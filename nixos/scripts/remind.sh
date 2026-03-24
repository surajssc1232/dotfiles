
#!/usr/bin/env bash

# 1. Get the task message using fuzzel
MESSAGE=$(echo "" | fuzzel -d -p "Task: " --placeholder "What do you need to do?")

# Exit if no message was entered (ESC or empty)
[ -z "$MESSAGE" ] && exit 0

# 2. Get the time delay
TIME=$(echo -e "5\n10\n15\n30\n60" | fuzzel -d -p "In (mins): " --placeholder "Enter minutes...")

# Exit if no time was entered
[ -z "$TIME" ] && exit 0

# 3. Background the reminder
(
  # Convert minutes to seconds
  sleep $((TIME * 60))
  
  # Send the notification using dunst (libnotify)
  # -u critical makes it stay until you dismiss it
  notify-send -u critical -a "Reminder" "⏰ Time's up!" "$MESSAGE"
) &

notify-send -t 2000 "Reminder Set" "I'll remind you about '$MESSAGE' in $TIME minutes."
