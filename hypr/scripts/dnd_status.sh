#!/bin/bash

if swaync-client -d | grep -q true; then
    echo '{"text":"󰂛","tooltip":"DND: ON"}'
else
    echo '{"text":"󰂚","tooltip":"DND: OFF"}'
fi

