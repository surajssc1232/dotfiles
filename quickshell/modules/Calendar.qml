import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

// Month grid, drawn by hand so every cell picks up the active theme.
Item {
	id: root

	// Current wall-clock date, passed in so the grid re-renders at midnight
	// rather than going stale until the popup is reopened.
	property date today: new Date()

	// Months away from the current one; reset whenever the popup reopens.
	property int monthOffset: 0

	// The date spelled out above the grid. Turned off where something else on
	// the same screen already says it — the lock screen prints it under the
	// clock, and twice over reads like a mistake.
	property bool showToday: true

	// Whether days can be clicked to see and add reminders. Off on the lock
	// screen: it shows the dots, but nothing there should take input other
	// than the password.
	property bool editable: false

	// The day whose events are listed under the grid, as "yyyy-MM-dd", or ""
	// for none. Right-click picks a day and opens the form straight away;
	// left-click on a marked day just lists what is on it.
	property string selected: ""
	property bool adding: false
	property string kind: "reminder"
	property string repeat: "none"

	// Wanted focus back on the popup's content when the form closes, so
	// Escape still reaches the calendar.
	signal closed()

	function select(dateKey: string, add: bool) {
		root.selected = dateKey;
		root.adding = add;
		root.kind = "reminder";
		root.repeat = "none";
	}

	function deselect() {
		root.selected = "";
		root.adding = false;
		root.closed();
	}

	readonly property date shownMonth: new Date(today.getFullYear(),
		today.getMonth() + monthOffset, 1)

	readonly property var locale: Qt.locale()
	readonly property int firstDay: locale.firstDayOfWeek

	// Wider while the reminder form can be shown, for its row of repeat
	// choices; the lock screen's copy keeps the narrow width.
	implicitWidth: editable ? 290 : 252
	implicitHeight: column.implicitHeight + Config.padding * 2

	function isSameDay(a: date, b: date): bool {
		return a.getFullYear() === b.getFullYear()
			&& a.getMonth() === b.getMonth()
			&& a.getDate() === b.getDate();
	}

	// 42 cells: six weeks, enough for any month in any first-day-of-week.
	readonly property var cells: {
		const first = shownMonth;
		// How far back the grid must start to land on the locale's first weekday.
		const lead = (first.getDay() - firstDay + 7) % 7;
		const start = new Date(first.getFullYear(), first.getMonth(), 1 - lead);

		const out = [];
		for (let i = 0; i < 42; i++) {
			const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
			out.push({
				key: Events.key(d),
				day: d.getDate(),
				inMonth: d.getMonth() === first.getMonth(),
				isToday: isSameDay(d, today)
			});
		}
		return out;
	}

	Rectangle {
		anchors.fill: parent
		radius: Config.radius
		color: Config.bg
		border.width: 1
		border.color: Config.border
	}

	ColumnLayout {
		id: column

		anchors.fill: parent
		anchors.margins: Config.padding
		spacing: 6

		focus: true
		Keys.onEscapePressed: event => {
			if (root.selected === "") {
				event.accepted = false;
				return;
			}
			root.deselect();
		}

		// ---- today, spelled out ----
		Label {
			Layout.fillWidth: true
			visible: root.showToday
			text: Qt.formatDateTime(root.today, "dddd, d MMMM yyyy")
			color: Config.accent
			elide: Text.ElideRight
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 1
			Layout.topMargin: 2
			Layout.bottomMargin: 4
			visible: root.showToday
			color: Config.border
		}

		// ---- month navigation ----
		RowLayout {
			Layout.fillWidth: true
			spacing: 0

			NavButton {
				icon: Config.icons.chevronLeft
				onTriggered: root.monthOffset--
			}

			Label {
				Layout.fillWidth: true
				text: Qt.formatDateTime(root.shownMonth, "MMMM yyyy")
				horizontalAlignment: Text.AlignHCenter
			}

			NavButton {
				// Jumps back to the current month; hidden when already there.
				icon: Config.icons.today
				visible: root.monthOffset !== 0
				onTriggered: root.monthOffset = 0
			}

			NavButton {
				icon: Config.icons.chevronRight
				onTriggered: root.monthOffset++
			}
		}

		// ---- weekday initials ----
		GridLayout {
			Layout.fillWidth: true
			columns: 7
			columnSpacing: 0
			rowSpacing: 0

			Repeater {
				model: 7

				Label {
					required property int index

					Layout.fillWidth: true
					Layout.preferredHeight: 20

					text: root.locale.dayName((root.firstDay + index) % 7, Locale.ShortFormat)
						.substring(0, 2)
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 2
					horizontalAlignment: Text.AlignHCenter
				}
			}
		}

		// ---- days ----
		GridLayout {
			Layout.fillWidth: true
			columns: 7
			columnSpacing: 0
			rowSpacing: 0

			Repeater {
				model: root.cells

				Item {
					id: cell

					required property var modelData

					readonly property bool marked: Events.hasOn(modelData.key)
					readonly property bool picked: root.selected === modelData.key

					Layout.fillWidth: true
					Layout.preferredHeight: 26

					Rectangle {
						anchors.centerIn: parent
						width: 24
						height: 24
						radius: 12
						color: cell.modelData.isToday ? Config.accent
							: hover.containsMouse && root.editable ? Config.bgAlt
							: "transparent"
						border.width: cell.picked ? 1.5 : 0
						border.color: cell.modelData.isToday ? Config.fg : Config.accent
					}

					Label {
						anchors.centerIn: parent
						anchors.verticalCenterOffset: cell.marked ? -2 : 0
						text: cell.modelData.day
						font.pixelSize: Config.fontSize - 1
						color: cell.modelData.isToday ? Config.bg
							: cell.modelData.inMonth ? Config.fg
							: Config.fgDim
					}

					// Something is on this day. The theme's accent, or the
					// background colour on today's already-accent circle.
					Rectangle {
						anchors.horizontalCenter: parent.horizontalCenter
						anchors.verticalCenter: parent.verticalCenter
						anchors.verticalCenterOffset: 7
						width: 4
						height: 4
						radius: 2
						visible: cell.marked
						color: cell.modelData.isToday ? Config.bg : Config.accent
						opacity: cell.modelData.inMonth ? 1 : 0.5
					}

					MouseArea {
						id: hover

						anchors.fill: parent
						enabled: root.editable
						hoverEnabled: true
						acceptedButtons: Qt.LeftButton | Qt.RightButton
						cursorShape: Qt.PointingHandCursor

						onClicked: mouse => {
							const key = cell.modelData.key;
							if (mouse.button === Qt.RightButton) root.select(key, true);
							else if (cell.picked && !root.adding) root.deselect();
							else if (cell.marked) root.select(key, false);
							else root.deselect();
						}
					}
				}
			}
		}

		// ---- the picked day: what is on it, and the form to add more ----
		DayEvents {
			Layout.fillWidth: true
			Layout.topMargin: 4
			visible: root.editable && root.selected !== ""
		}

		Label {
			Layout.fillWidth: true
			visible: root.editable && root.selected === ""
			text: "Right-click a day to add a reminder"
			color: Config.fgDim
			font.pixelSize: Config.fontSize - 4
			horizontalAlignment: Text.AlignHCenter
		}
	}

	component DayEvents: ColumnLayout {
		id: day

		readonly property var list: Events.on(root.selected)
		readonly property date when: {
			const [y, m, d] = root.selected.split("-").map(Number);
			return new Date(y || 1970, (m || 1) - 1, d || 1);
		}

		spacing: 6

		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 1
			color: Config.border
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 4

			Label {
				Layout.fillWidth: true
				text: Qt.formatDate(day.when, "dddd, d MMMM")
				color: Config.accent
				font.pixelSize: Config.fontSize - 1
				elide: Text.ElideRight
			}

			NavButton {
				icon: Config.icons.plus
				visible: !root.adding
				onTriggered: root.adding = true
			}

			NavButton {
				icon: Config.icons.close
				onTriggered: root.deselect()
			}
		}

		Label {
			visible: day.list.length === 0 && !root.adding
			text: "Nothing on this day"
			color: Config.fgDim
			font.pixelSize: Config.fontSize - 3
		}

		Repeater {
			model: day.list

			RowLayout {
				id: entry

				required property var modelData

				Layout.fillWidth: true
				spacing: 8

				Label {
					Layout.preferredWidth: 14
					text: entry.modelData.kind === "meeting"
						? Config.icons.meeting : Config.icons.bell
					color: Config.accent
					font.pixelSize: Config.fontSize - 3
				}

				Label {
					Layout.fillWidth: true
					Layout.minimumWidth: 0
					text: entry.modelData.title
					font.pixelSize: Config.fontSize - 2
					elide: Text.ElideRight
				}

				// When, and how often, at the far end beside the delete
				// button: the title reads first, and a missing time is a
				// quiet "All day" rather than a column of it down the left.
				Label {
					readonly property bool repeats: (entry.modelData.repeat ?? "none") !== "none"

					text: (entry.modelData.time || "All day")
						+ (repeats ? "  " + Config.icons.repeat + " "
							+ Events.repeatNames[entry.modelData.repeat] : "")
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 4
				}

				NavButton {
					icon: Config.icons.trash
					onTriggered: Events.remove(entry.modelData.id)
				}
			}
		}

		// ---- new entry ----
		ColumnLayout {
			Layout.fillWidth: true
			visible: root.adding
			spacing: 6

			Field {
				id: title

				Layout.fillWidth: true
				placeholder: root.kind === "meeting" ? "Meeting title" : "Remind me to…"
				onAccepted: day.submit()
				KeyNavigation.tab: time.input
			}

			RowLayout {
				Layout.fillWidth: true
				spacing: 6

				Field {
					id: time

					Layout.preferredWidth: 72
					placeholder: "HH:MM"
					onAccepted: day.submit()
					KeyNavigation.tab: title.input
				}

				KindChip { value: "reminder"; text: "Reminder" }
				KindChip { value: "meeting"; text: "Meeting" }

				Item { Layout.fillWidth: true }
			}

			RowLayout {
				Layout.fillWidth: true
				spacing: 4

				Repeater {
					model: Events.repeats

					RepeatChip {
						required property string modelData
						value: modelData
					}
				}
			}

			RowLayout {
				Layout.fillWidth: true
				spacing: 6

				Label {
					Layout.fillWidth: true
					text: time.text.trim() && !Events.normaliseTime(time.text)
						? "Time not understood; saved as all day"
						: time.text.trim() ? "Notified at " + Events.normaliseTime(time.text)
							+ (root.repeat === "none" ? "" : ", " + root.repeatNames())
						: "No time: shown on the day, not notified"
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 5
					elide: Text.ElideRight
				}

				MouseArea {
					implicitWidth: addLabel.implicitWidth + 18
					implicitHeight: 24
					enabled: title.text.trim().length > 0
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: day.submit()

					Rectangle {
						anchors.fill: parent
						radius: Config.radius - 4
						color: parent.enabled ? Config.accent : Config.bgAlt
						opacity: parent.containsMouse ? 0.85 : 1
					}

					Label {
						id: addLabel
						anchors.centerIn: parent
						text: "Add"
						color: parent.enabled ? Config.bg : Config.fgDim
						font.pixelSize: Config.fontSize - 2
					}
				}
			}
		}

		function submit() {
			if (!title.text.trim()) return;
			Events.add(root.selected, time.text, title.text, root.kind, root.repeat);
			title.text = "";
			time.text = "";
			root.adding = false;
			root.closed();
		}

		// Clear the form whenever it is opened for a different day.
		Connections {
			target: root
			function onAddingChanged() {
				if (!root.adding) return;
				title.text = "";
				time.text = "";
				title.input.forceActiveFocus();
			}
			function onSelectedChanged() {
				if (root.adding) title.input.forceActiveFocus();
			}
		}
	}

	// A one-line text box in the theme's colours.
	component Field: Rectangle {
		id: box

		property string placeholder
		property alias text: input.text
		property alias input: input
		signal accepted()

		implicitHeight: 26
		radius: Config.radius - 4
		color: Config.bgAlt
		border.width: 1
		border.color: input.activeFocus ? Config.accent : Config.border

		TextInput {
			id: input

			anchors.fill: parent
			anchors.leftMargin: 8
			anchors.rightMargin: 8
			verticalAlignment: TextInput.AlignVCenter
			color: Config.fg
			font.family: Config.font
			font.pixelSize: Config.fontSize - 2
			selectByMouse: true
			selectionColor: Config.accent
			clip: true

			onAccepted: box.accepted()
			Keys.onEscapePressed: root.deselect()

			Label {
				anchors.verticalCenter: parent.verticalCenter
				visible: input.text.length === 0
				text: box.placeholder
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 2
			}
		}
	}

	// "every day", "every Friday", "on the 26th of each month", worked out
	// from the picked day so it says exactly what will happen.
	function repeatNames(): string {
		const [y, m, d] = root.selected.split("-").map(Number);
		const when = new Date(y || 1970, (m || 1) - 1, d || 1);
		switch (root.repeat) {
		case "daily": return "every day";
		case "weekly": return "every " + Qt.formatDate(when, "dddd");
		case "monthly": return "on the " + d + root.ordinal(d) + " monthly";
		case "yearly": return "every " + Qt.formatDate(when, "d MMMM");
		default: return "";
		}
	}

	function ordinal(n: int): string {
		if (n % 100 >= 11 && n % 100 <= 13) return "th";
		return ["th", "st", "nd", "rd"][n % 10] ?? "th";
	}

	// Once, daily, weekly, monthly or yearly: a row of small chips, since
	// every option fits and a dropdown would be one more click for each.
	component RepeatChip: MouseArea {
		id: rchip

		property string value

		readonly property bool on: root.repeat === value

		Layout.fillWidth: true
		implicitWidth: rlabel.implicitWidth + 10
		implicitHeight: 22
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: root.repeat = rchip.value

		Rectangle {
			anchors.fill: parent
			radius: height / 2
			color: rchip.on ? Config.accent : rchip.containsMouse ? Config.bgAlt : "transparent"
			border.width: rchip.on ? 0 : 1
			border.color: Config.border
		}

		Label {
			id: rlabel
			anchors.centerIn: parent
			text: Events.repeatNames[rchip.value]
			color: rchip.on ? Config.bg : Config.fgDim
			font.pixelSize: Config.fontSize - 4
		}
	}

	// Reminder or meeting. Changes what the title asks for, the icon in the
	// list, and how loudly the notification arrives.
	component KindChip: MouseArea {
		id: chip

		property string value
		property string text

		readonly property bool on: root.kind === value

		implicitWidth: chipLabel.implicitWidth + 16
		implicitHeight: 24
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: root.kind = chip.value

		Rectangle {
			anchors.fill: parent
			radius: height / 2
			color: chip.on ? Config.accent : chip.containsMouse ? Config.bgAlt : "transparent"
			border.width: chip.on ? 0 : 1
			border.color: Config.border
		}

		Label {
			id: chipLabel
			anchors.centerIn: parent
			text: chip.text
			color: chip.on ? Config.bg : Config.fgDim
			font.pixelSize: Config.fontSize - 3
		}
	}

	// Small icon button used by the month navigation row.
	component NavButton: MouseArea {
		property string icon
		signal triggered()

		Layout.preferredWidth: 24
		Layout.preferredHeight: 24

		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: triggered()

		Rectangle {
			anchors.fill: parent
			radius: Config.radius - 4
			color: parent.containsMouse ? Config.bgAlt : "transparent"
		}

		Label {
			anchors.centerIn: parent
			text: parent.icon
			color: parent.containsMouse ? Config.accent : Config.fgDim
			font.pixelSize: Config.fontSize - 2
		}
	}
}
