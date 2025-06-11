#!/bin/bash

# Get current DND status
STATUS=$(swaync-client -d)

if [[ "$STATUS" == "true" ]]; then
    swaync-client -D false  # Disable DND
else
    swaync-client -D true   # Enable DND
fi

