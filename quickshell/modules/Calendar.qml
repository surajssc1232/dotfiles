import QtQuick
import QtQuick.Layouts
import qs
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

	readonly property date shownMonth: new Date(today.getFullYear(),
		today.getMonth() + monthOffset, 1)

	readonly property var locale: Qt.locale()
	readonly property int firstDay: locale.firstDayOfWeek

	implicitWidth: 252
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

					Layout.fillWidth: true
					Layout.preferredHeight: 26

					Rectangle {
						anchors.centerIn: parent
						width: 24
						height: 24
						radius: 12
						color: cell.modelData.isToday ? Config.accent : "transparent"
					}

					Label {
						anchors.centerIn: parent
						text: cell.modelData.day
						font.pixelSize: Config.fontSize - 1
						color: cell.modelData.isToday ? Config.bg
							: cell.modelData.inMonth ? Config.fg
							: Config.fgDim
					}
				}
			}
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
