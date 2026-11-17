#!/usr/bin/env python3
"""Storage review for the shell's storage panel. Read-only: it only measures.

One pass over $HOME, split across threads, replaces the old shell script's six
(three finds, a large-file find, then du over every folder and every cache
directory, each re-walking what the last one had just read). Every directory
is read once and every file stat'ed once; all the kinds below come out of that
same walk.

Prints one item per line, tab separated, as soon as it is known:
    kind  bytes  mtime  path

kinds: trash, cache, dev, junk, broken, build   (safe to remove)
       large, folder                            (for review)
       dir                                      (sub-folders, for drilling in)
and, between them:
    progress  done  total  name

With an output path as the first argument, the complete result is also written
there (atomically, once the scan is finished) so the panel can show the last
scan instantly the next time it opens.
"""

import os
import stat
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor

sys.setrecursionlimit(20000)

HOME = os.path.realpath(os.environ.get("HOME", "/"))
OUT = sys.argv[1] if len(sys.argv) > 1 else ""

LARGE = 100 * 1024 * 1024   # files at least this big are listed
DIR_MIN = 8 * 1024 * 1024   # sub-folders smaller than this are not worth drilling into
DIR_DEPTH = 6               # deepest sub-folder level (from $HOME) reported

# Measured, but never searched for junk, broken links or build output: these
# are managed by something else, or (the trash) offered as one item.
PRUNE = {os.path.join(HOME, p) for p in (
    ".cache", ".local/share/Trash", ".cargo", ".rustup", ".steam", ".var",
    ".local/share/Steam", ".local/share/flatpak", ".local/share/umu",
    ".local/share/containers", ".local/share/docker", ".wine", "Games",
    ".nix-defexpr", ".local/state/nix",
)}
# Junk, broken links and build output are looked for this deep and no deeper,
# as the old find's -maxdepth 8 did. Sizes are always measured all the way down.
SEARCH_DEPTH = 8
# Not counted as large files either: they are offered as a whole.
NO_LARGE = {os.path.join(HOME, p) for p in (".cache", ".local/share/Trash")}

TRASH = os.path.join(HOME, ".local/share/Trash")
CACHE = os.path.join(HOME, ".cache")
# quickshell's own cache holds the clipboard history's images: never offered.
CACHE_KEEP = {os.path.join(CACHE, "quickshell")}
DEV = {os.path.join(HOME, p) for p in (
    ".npm/_cacache", ".cargo/registry/cache", ".cargo/registry/src",
    ".gradle/caches", ".local/share/pnpm/store", ".m2/repository",
)}

JUNK_SUFFIX = ("~", ".bak", ".swp", ".swo", ".tmp", ".orig", ".rej")
JUNK_NAMES = {".DS_Store", "Thumbs.db", "core"}

try:
    DEVICE = os.stat(HOME).st_dev
except OSError:
    sys.exit(0)

lock = threading.Lock()
seen_inodes = set()   # hard-linked files are counted once, as du does
results = []


def emit(kind, size, mtime, path):
    line = "%s\t%d\t%d\t%s" % (kind, size, int(mtime), path)
    with lock:
        results.append(line)
        sys.stdout.write(line + "\n")
        sys.stdout.flush()


def is_junk(name):
    return (name in JUNK_NAMES or name.endswith(JUNK_SUFFIX)
            or (name.startswith("core.") and name[5:].isdigit()))


def walk(path, st, depth, search, large):
    """Disk use of the directory at `path`, emitting what is found inside.

    `search` is False under pruned places and inside build output, where junk,
    broken links and nested builds are not looked for; `large` is False where
    large files are not listed.
    """
    total = st.st_blocks * 512
    try:
        it = os.scandir(path)
    except OSError:
        return total

    subdirs = []
    with it:
        for e in it:
            try:
                s = e.stat(follow_symlinks=False)
            except OSError:
                continue
            mode = s.st_mode

            if stat.S_ISDIR(mode):
                if s.st_dev == DEVICE:
                    subdirs.append((e.path, e.name, s))
                continue

            if s.st_nlink > 1:
                key = (s.st_dev, s.st_ino)
                with lock:
                    if key in seen_inodes:
                        continue
                    seen_inodes.add(key)

            size = s.st_blocks * 512
            total += size

            if stat.S_ISLNK(mode):
                if search and not e.name.startswith("Singleton") \
                        and not os.path.exists(e.path):
                    emit("broken", 0, s.st_mtime, e.path)
                continue

            if not stat.S_ISREG(mode):
                continue
            if large and s.st_size >= LARGE:
                emit("large", size, s.st_mtime, e.path)
            elif search and is_junk(e.name):
                emit("junk", size, s.st_mtime, e.path)

    for p, name, s in subdirs:
        total += child(p, name, s, depth + 1, search, large, path)
    return total


def child(p, name, s, depth, search, large, parent):
    """Measures one sub-directory and decides what, if anything, it is."""
    if name == ".git":
        search = False
    sub_search = search and p not in PRUNE and depth < SEARCH_DEPTH
    sub_large = large and p not in NO_LARGE

    build = False
    if sub_search:
        if name in ("node_modules", "__pycache__"):
            build = True
        elif name == "target" and os.path.isfile(os.path.join(parent, "Cargo.toml")):
            build = True

    size = walk(p, s, depth, sub_search and not build, sub_large)
    report(p, s, size, depth, build)
    return size


def report(p, s, size, depth, build):
    if build:
        emit("build", size, s.st_mtime, p)
    if p in DEV:
        emit("dev", size, s.st_mtime, p)
    elif p == TRASH:
        emit("trash", size, s.st_mtime, p)
    elif os.path.dirname(p) == CACHE and p not in CACHE_KEEP:
        emit("cache", size, s.st_mtime, p)

    if depth == 1:
        emit("folder", size, s.st_mtime, p)
    elif depth <= DIR_DEPTH and size >= DIR_MIN:
        emit("dir", size, s.st_mtime, p)


started = time.time()


def main():
    # The work is split one level below $HOME: a single folder such as
    # ~/.local or ~/Games is often most of the disk, and splitting only at the
    # top would leave one thread doing nearly all of it.
    tops = []
    for e in os.scandir(HOME):
        try:
            s = e.stat(follow_symlinks=False)
        except OSError:
            continue
        if stat.S_ISDIR(s.st_mode) and s.st_dev == DEVICE:
            tops.append((e.path, e.name, s))

    jobs = []           # (top index, path, name, stat)
    top_own = {}        # top path -> bytes of its own files and itself
    for i, (p, name, s) in enumerate(tops):
        search = p not in PRUNE and name != ".git"
        large = p not in NO_LARGE
        own = s.st_blocks * 512
        try:
            with os.scandir(p) as it:
                for e in it:
                    try:
                        cs = e.stat(follow_symlinks=False)
                    except OSError:
                        continue
                    if stat.S_ISDIR(cs.st_mode):
                        if cs.st_dev == DEVICE:
                            jobs.append((i, e.path, e.name, cs, search, large))
                        continue
                    if cs.st_nlink > 1:
                        key = (cs.st_dev, cs.st_ino)
                        if key in seen_inodes:
                            continue
                        seen_inodes.add(key)
                    own += cs.st_blocks * 512
                    if stat.S_ISLNK(cs.st_mode):
                        if search and not e.name.startswith("Singleton") \
                                and not os.path.exists(e.path):
                            emit("broken", 0, cs.st_mtime, e.path)
                    elif stat.S_ISREG(cs.st_mode):
                        if large and cs.st_size >= LARGE:
                            emit("large", cs.st_blocks * 512, cs.st_mtime, e.path)
                        elif search and is_junk(e.name):
                            emit("junk", cs.st_blocks * 512, cs.st_mtime, e.path)
        except OSError:
            pass
        top_own[p] = own

    sums = [top_own[p] for p, _, _ in tops]
    left = [0] * len(tops)
    for j in jobs:
        left[j[0]] += 1

    total = len(jobs) + len(tops)
    done = [0]

    def progress(name):
        done[0] += 1
        with lock:
            sys.stdout.write("progress\t%d\t%d\t%s\n" % (done[0], total, name))
            sys.stdout.flush()

    def finish_top(i):
        p, name, s = tops[i]
        report(p, s, sums[i], 1, False)
        progress(name)

    def run(job):
        i, p, name, s, search, large = job
        size = child(p, name, s, 2, search, large, tops[i][0])
        with lock:
            sums[i] += size
            left[i] -= 1
            last = left[i] == 0
        progress(tops[i][1] + "/" + name)
        if last:
            finish_top(i)

    # Directories with no sub-directories have nothing to wait for.
    for i in range(len(tops)):
        if left[i] == 0:
            finish_top(i)

    # The slow part is waiting on the disk, which releases the GIL, so threads
    # do overlap here. Biggest-looking first, so a huge folder is not the one
    # left running alone at the end.
    jobs.sort(key=lambda j: -j[3].st_nlink)
    workers = min(16, (os.cpu_count() or 4) * 2)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        list(pool.map(run, jobs))

    if OUT:
        tmp = OUT + ".tmp"
        try:
            with open(tmp, "w") as f:
                f.write("scanned\t0\t%d\t%s\n" % (int(started), HOME))
                f.write("\n".join(results) + "\n")
            os.replace(tmp, OUT)
        except OSError:
            pass


if __name__ == "__main__":
    try:
        main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
