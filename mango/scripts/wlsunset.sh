#!/usr/bin/env bash
if pgrep -x wlsunset > /dev/null; then
    pkill -x wlsunset
else
    wlsunset &
fi
```

Then bind it with:
```
bind=ALT,O,spawn,~/.config/mango/toggle-wlsunset.sh
