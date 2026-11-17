#!/usr/bin/env python3
"""Live input level for the mixer: prints one peak (0..1) per line, ~20 a second.

Usage: level-meter.py <pipewire node name>

Quickshell's own peak monitor only understands left/right style channel maps,
so it reads nothing at all from a Pro Audio device, whose channels are
aux0, aux1, ... pw-cat records from any device and folds it down to one
channel for us, so this works whatever the profile.

The capture stream names itself quickshell-meter, which the shell knows to
leave out of its list of apps using the microphone.
"""

import os
import signal
import subprocess
import sys

RATE = 16000
CHUNK = RATE // 20  # samples per reading: 50 ms

target = sys.argv[1] if len(sys.argv) > 1 else ""
cmd = ["pw-cat", "--record", "--raw", "--format", "s16", "--rate", str(RATE),
       "--channels", "1", "--latency", "50ms",
       "-P", "{ application.name = quickshell-meter node.name = quickshell-meter "
             "node.description = quickshell-meter media.role = Production }"]
if target:
    cmd += ["--target", target]
cmd.append("-")

child = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)


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
        # Quickshell gone: stop recording rather than run on unseen.
        if os.getppid() == 1:
            break
except (BrokenPipeError, KeyboardInterrupt):
    pass
finally:
    child.terminate()
