#!/usr/bin/env sh
exec qs ipc call screenshot delayed "${1:-3}"
