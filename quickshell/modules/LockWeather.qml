import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.widgets

// Current conditions and the next few hours, beside the calendar. Asks
// for a fresh reading as it appears: a lock is often the first thing seen
// after a suspend, and the last reading may be hours old by then.
Rectangle {
	// Drops the hourly strip, for when something else shares the column and
	// the whole of it has to fit beside the calendar.
	property bool compact: false

	implicitWidth: 260
	implicitHeight: body.implicitHeight + Config.padding * 2

	radius: Config.radius
	color: Config.bg
	border.width: 1
	border.color: Config.border

	Component.onCompleted: Weather.refresh()

	ColumnLayout {
		id: body

		anchors.fill: parent
		anchors.margins: Config.padding
		spacing: 8

		RowLayout {
			Layout.fillWidth: true
			spacing: 6

			Label {
				text: Weather.icon
				color: Config.accent
				font.pixelSize: Config.fontSize - 2
			}

			Label {
				text: "Weather"
				color: Config.accent
			}

			Label {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				horizontalAlignment: Text.AlignRight
				text: Weather.place
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 2
				elide: Text.ElideRight
			}
		}

		RowLayout {
			Layout.fillWidth: true
			spacing: 12

			Label {
				text: Weather.error !== "" ? Config.icons.warning : Weather.icon
				color: Weather.error !== "" ? Config.red : Config.accent
				font.pixelSize: 34
			}

			ColumnLayout {
				Layout.fillWidth: true
				Layout.minimumWidth: 0
				spacing: 0

				Label {
					text: Weather.valid ? Math.round(Weather.temperature) + "°" : "—"
					font.pixelSize: Config.fontSize + 14
				}

				Label {
					Layout.fillWidth: true
					text: Weather.valid ? Weather.summary : Weather.error
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 1
					wrapMode: Text.WordWrap
					maximumLineCount: 2
					elide: Text.ElideRight
				}
			}
		}

		Label {
			readonly property var today: Weather.forecast[0] ?? null

			visible: Weather.valid && today !== null
			text: today === null ? ""
				: "H " + Math.round(today.max) + "°  ·  L " + Math.round(today.min) + "°"
					+ "  ·  Feels " + Math.round(Weather.feelsLike) + "°"
			color: Config.fgDim
			font.pixelSize: Config.fontSize - 3
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.preferredHeight: 1
			visible: hours.visible
			color: Config.border
		}

		RowLayout {
			id: hours

			Layout.fillWidth: true
			visible: Weather.valid && Weather.hourly.length > 0 && !compact
			spacing: 0

			Repeater {
				model: Weather.hourly.slice(0, 5)

				ColumnLayout {
					required property var modelData

					Layout.fillWidth: true
					Layout.preferredWidth: 1
					spacing: 2

					Label {
						Layout.alignment: Qt.AlignHCenter
						text: modelData.hour
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 4
					}

					Label {
						Layout.alignment: Qt.AlignHCenter
						text: Weather.iconFor(modelData.code, true)
						color: Config.accent
						font.pixelSize: Config.fontSize
					}

					Label {
						Layout.alignment: Qt.AlignHCenter
						text: Math.round(modelData.temp) + "°"
						font.pixelSize: Config.fontSize - 2
					}
				}
			}
		}
	}
}
