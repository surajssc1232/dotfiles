#!/usr/bin/env sh
# Saves an image arriving on stdin into the shell's clipboard cache and prints
# where it went. Run by wl-paste --watch, which pipes the clipboard in.
dir="$1"
[ -n "$dir" ] || exit 1
mkdir -p "$dir" || exit 1

file="$dir/$(date +%s%N).png"
cat > "$file" || exit 1

# Nothing useful arrived; do not leave an empty file behind to show in the list.
if [ ! -s "$file" ]; then
	rm -f "$file"
	exit 0
fi

# wl-paste --watch fires once the moment it starts, so every shell reload
# re-saves whatever is already on the clipboard. Identical to the newest one
# already stored means it is that, not a new copy.
newest=$(ls -1t "$dir"/*.png 2>/dev/null | grep -v "^$file$" | head -n 1)
if [ -n "$newest" ] && cmp -s "$file" "$newest"; then
	rm -f "$file"
	exit 0
fi

printf '%s\n' "$file"
