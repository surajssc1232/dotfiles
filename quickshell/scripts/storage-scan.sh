#!/bin/sh
# Storage review for the shell's storage panel. Read-only: it only measures.
# Prints one item per line, tab separated:
#   kind  bytes  mtime  path
#
# kinds: trash, cache, dev, junk, broken, build   (safe to remove)
#        large, folder                            (for review)

H="$HOME"

# Disk use, not apparent size, so the numbers match what removing frees.
size() { du -sx -B1 -- "$1" 2>/dev/null | cut -f1; }
mtime() { stat -c %Y -- "$1" 2>/dev/null; }

emit() {
	[ -e "$2" ] || [ -L "$2" ] || return
	printf '%s\t%s\t%s\t%s\n' "$1" "$(size "$2")" "$(mtime "$2")" "$2"
}

# find over $HOME, skipping places that are managed elsewhere.
walk() {
	find "$H" -xdev -maxdepth 8 \
		\( -path "$H/.cache" -o -path "$H/.local/share/Trash" -o -name .git \
		-o -path "$H/.cargo" -o -path "$H/.rustup" -o -path "$H/.steam" \
		-o -path "$H/.var" -o -path "$H/.local/share/Steam" \) -prune -o "$@"
}

emit trash "$H/.local/share/Trash"

# ~/.cache, one entry per app. quickshell's own cache holds the clipboard
# history's images, so it is never offered.
for d in "$H"/.cache/*/; do
	d="${d%/}"
	[ "$(basename "$d")" = quickshell ] && continue
	emit cache "$d"
done

for d in "$H/.npm/_cacache" "$H/.cargo/registry/cache" "$H/.cargo/registry/src" \
	"$H/.gradle/caches" "$H/.local/share/pnpm/store" "$H/.m2/repository"; do
	emit dev "$d"
done

walk \( -name node_modules \) -prune -o -type f \
	\( -name '*~' -o -name '*.bak' -o -name '*.swp' -o -name '*.swo' -o -name '*.tmp' \
	-o -name '*.orig' -o -name '*.rej' -o -name .DS_Store -o -name Thumbs.db \
	-o -name core -o -name 'core.[0-9]*' \) \
	-printf 'junk\t%s\t%T@\t%p\n'

walk -xtype l -printf 'broken\t0\t%T@\t%p\n'

walk -type d \( -name node_modules -o -name __pycache__ \
	-o \( -name target -execdir test -f Cargo.toml \; \) \) -prune -print |
while IFS= read -r d; do emit build "$d"; done

find "$H" -xdev -type f -size +100M \
	-not -path "$H/.cache/*" -not -path "$H/.local/share/Trash/*" \
	-printf 'large\t%s\t%T@\t%p\n'

for d in "$H"/* "$H"/.[!.]*; do
	[ -d "$d" ] && emit folder "$d"
done
