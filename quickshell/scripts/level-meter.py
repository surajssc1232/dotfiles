#!/usr/bin/env python3
"""Live input level for the mixer: prints one peak (0..1) per line, ~40 a second.

Usage: level-meter.py <pipewire node name>

Quickshell's own peak monitor only understands left/right style channel maps,
so it reads nothing at all from a Pro Audio device, whose channels are
aux0, aux1, ... pw-cat records from any device and folds it down to one
channel for us, so this works whatever the profile.

The capture stream names itself quickshell-meter, which the shell knows to
leave out of its list of apps using the microphone.
"""

import ctypes
import os
import signal
import subprocess
import sys

PR_SET_PDEATHSIG = 1


def die_with_parent():
    """Asks the kernel to end this process the moment its parent goes, so a
    meter can never keep the microphone open after the shell has stopped."""
    try:
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(PR_SET_PDEATHSIG, signal.SIGTERM)
    except OSError:
        pass


die_with_parent()

RATE = 16000
CHUNK = RATE // 40  # samples per reading: 25 ms, so ~40 readings a second

target = sys.argv[1] if len(sys.argv) > 1 else ""
cmd = ["pw-cat", "--record", "--raw", "--format", "s16", "--rate", str(RATE),
       "--channels", "1", "--latency", "20ms",
       "-P", "{ application.name = quickshell-meter node.name = quickshell-meter "
             "node.description = quickshell-meter media.role = Production }"]
if target:
    cmd += ["--target", target]
cmd.append("-")

child = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                         preexec_fn=die_with_parent)


def stop(*_):
    child.terminate()
    sys.exit(0)


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
signal.signal(signal.SIGHUP, stop)

try:
    while True:
        data = child.stdout.read(CHUNK * 2)
        if not data:
            break
        # Peak of the chunk, as a fraction of full scale.
        mv = memoryview(data[: len(data) // 2 * 2]).cast("h")
        peak = max(max(mv), -min(mv)) if len(mv) else 0
        sys.stdout.write("%.4f\n" % (peak / 32768))
        sys.stdout.flush()
except (BrokenPipeError, KeyboardInterrupt):
    pass
finally:
    child.terminate()
    # Nothing left to report to; quietly, rather than a traceback on exit.
    try:
        sys.stdout.close()
    except Exception:
        pass
