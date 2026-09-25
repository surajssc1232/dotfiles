import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.widgets

// The weather in full, shown as the weather tile's detail pane.
Item {
	id: root

	// Set by the control centre while the pane is open.
	property bool active: false

	// True while the city field is up, so the panel can ask for the keyboard.
	property bool editing: false
	readonly property bool wantsKeyboard: root.editing

	readonly property int hoursShown: 8

	// Worked out from the panel's own width rather than left to fillWidth,
	// which would not distribute the extra space across the Repeater's
	// columns and left the strip bunched into the left half of the card.
	readonly property real hourColumnWidth:
		Math.max(30, (root.width - 16 - 4 * (root.hoursShown - 1)) / root.hoursShown)

	implicitHeight: body.implicitHeight

	onActiveChanged: {
		if (active) Weather.refresh();
		else {
			root.editing = false;
			Weather.places = [];
		}
	}

	function degrees(value: real): string {
		return Math.round(value) + "°";
	}

	function dayName(iso: string, index: int): string {
		if (index === 0) return "Today";
		return Qt.formatDateTime(new Date(iso + "T00:00:00"), "ddd");
	}

	function pick(place) {
		Weather.usePlace(place);
		root.editing = false;
	}

	ColumnLayout {
		id: body

		anchors.fill: parent
		spacing: 10

		// ---- now ----
		RowLayout {
			Layout.fillWidth: true
			Layout.leftMargin: 8
			Layout.rightMargin: 8
			spacing: 12

			Label {
				Layout.rightMargin: 4
				text: Weather.error !== "" ? Config.icons.warning : Weather.icon
				color: Weather.error !== "" ? Config.red : Config.accent
				font.pixelSize: 40
			}

			ColumnLayout {
				spacing: 0

				Label {
					text: Weather.valid ? root.degrees(Weather.temperature) : "—"
					font.pixelSize: Config.fontSize + 18
				}

				Label {
					text: Weather.valid ? Weather.summary : (Weather.error || "Loading…")
					color: Config.fgDim
					font.pixelSize: Config.fontSize
				}
			}

			Item { Layout.fillWidth: true }

			// ---- where ----
			ColumnLayout {
				Layout.alignment: Qt.AlignTop
				spacing: 2

				RowLayout {
					Layout.alignment: Qt.AlignRight
					spacing: 6

					Label {
						text: Weather.place || "Location unknown"
						font.pixelSize: Config.fontSize + 1
					}

					MouseArea {
						implicitWidth: 20
						implicitHeight: 18

						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							root.editing = !root.editing;
							if (!root.editing) Weather.places = [];
						}

						Label {
							anchors.centerIn: parent
							text: Config.icons.search
							color: parent.containsMouse || root.editing
								? Config.accent : Config.fgDim
							font.pixelSize: Config.fontSize - 3
						}
					}
				}

				// A guessed location is the one most likely to be wrong, so it
				// says so rather than quietly being somewhere else.
				Label {
					Layout.alignment: Qt.AlignRight
					text: Weather.manual ? "chosen" : "guessed from your IP"
					color: Weather.manual ? Config.fgDim : Config.yellow
					font.pixelSize: Config.fontSize - 2
					visible: Weather.place !== ""
				}
			}
		}

		// ---- city picker ----
		Item {
			Layout.fillWidth: true
			Layout.leftMargin: 8
			Layout.rightMargin: 8
			Layout.preferredHeight: root.editing ? 28 : 0

			visible: root.editing
			clip: true

			Rectangle {
				anchors.fill: parent
				radius: Config.radius - 4
				color: Config.bg
				border.width: 1
				border.color: field.activeFocus ? Config.accent : Config.border

				TextInput {
					id: field

					anchors.fill: parent
					anchors.leftMargin: 10
					anchors.rightMargin: 10

					verticalAlignment: TextInput.AlignVCenter
					color: Config.fg
					font.family: Config.font
					font.pixelSize: Config.fontSize - 2
					selectByMouse: true
					selectionColor: Config.accent
					clip: true

					onVisibleChanged: if (visible) {
						forceActiveFocus();
						settle.restart();
					}

					onTextChanged: lookup.restart()
					onAccepted: if (Weather.places.length > 0)
						root.pick(Weather.places[0])

					Keys.onEscapePressed: {
						field.text = "";
						Weather.places = [];
						root.editing = false;
					}

					Label {
						anchors.verticalCenter: parent.verticalCenter
						text: "Type a city, then Enter"
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 3
						visible: !field.text
					}
				}
			}
		}

		// The surface may still be being handed the keyboard when the field
		// appears, so the grab is retried a frame later.
		Timer {
			id: settle

			interval: 60
			onTriggered: if (root.editing) field.forceActiveFocus()
		}

		Timer {
			id: lookup

			interval: 350
			onTriggered: Weather.search(field.text)
		}

		Repeater {
			model: root.editing ? Weather.places : []

			MouseArea {
				id: hit

				required property var modelData

				Layout.fillWidth: true
				Layout.preferredHeight: 26

				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: root.pick(hit.modelData)

				Rectangle {
					anchors.fill: parent
					anchors.leftMargin: 6
					anchors.rightMargin: 6
					radius: Config.radius - 4
					color: hit.containsMouse ? Config.bgAlt : "transparent"
				}

				RowLayout {
					anchors.fill: parent
					anchors.leftMargin: 12
					anchors.rightMargin: 12
					spacing: 6

					Label {
						text: hit.modelData.label
						font.pixelSize: Config.fontSize - 2
					}

					Label {
						Layout.fillWidth: true
						Layout.minimumWidth: 0
						text: hit.modelData.detail
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 4
						elide: Text.ElideRight
					}
				}
			}
		}

		MouseArea {
			Layout.fillWidth: true
			Layout.preferredHeight: root.editing && Weather.manual ? 20 : 0

			visible: root.editing && Weather.manual
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: {
				field.text = "";
				Weather.forgetPlace();
				root.editing = false;
			}

			Label {
				anchors.left: parent.left
				anchors.leftMargin: 12
				anchors.verticalCenter: parent.verticalCenter
				text: "Use my approximate location instead"
				color: parent.containsMouse ? Config.fg : Config.fgDim
				font.pixelSize: Config.fontSize - 4
			}
		}

		// ---- the numbers ----
		GridLayout {
			Layout.fillWidth: true
			Layout.leftMargin: 8
			Layout.rightMargin: 8
			Layout.topMargin: 2

			visible: Weather.valid
			columns: 4
			rowSpacing: 12
			columnSpacing: 20

			Stat {
				Layout.fillWidth: true
				Layout.preferredWidth: 1
				label: "Feels like"
				value: root.degrees(Weather.feelsLike)
			}

			Stat {
				Layout.fillWidth: true
				Layout.preferredWidth: 1
				label: "Humidity"
				value: Weather.humidity + "%"
			}

			Stat {
				Layout.fillWidth: true
				Layout.preferredWidth: 1
				label: "Wind"
				value: Math.round(Weather.wind) + " km/h "
					+ Weather.bearing(Weather.windDirection)
			}

			Stat {
				Layout.fillWidth: true
				Layout.preferredWidth: 1
				label: "Rain"
				value: Weather.rainChance + "%"
				tint: Weather.rainChance >= 60 ? Config.blue : Config.fg
			}

			Stat {
				Layout.fillWidth: true
				Layout.preferredWidth: 1
				label: "UV index"
				value: Weather.uvMax.toFixed(1)
				tint: Weather.uvMax >= 8 ? Config.red
					: Weather.uvMax >= 6 ? Config.yellow : Config.fg
			}

			Stat {
				Layout.fillWidth: true
				Layout.preferredWidth: 1
				label: "Sunrise"
				value: Weather.sunrise
			}

			Stat {
				Layout.fillWidth: true
				Layout.preferredWidth: 1
				label: "Sunset"
				value: Weather.sunset
			}

			Stat {
				Layout.fillWidth: true
				Layout.preferredWidth: 1
				label: "Rainfall"
				value: Weather.precipitation.toFixed(1) + " mm"
			}
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.topMargin: 2
			Layout.preferredHeight: 1
			visible: Weather.hourly.length > 0
			color: Config.border
		}

		// ---- next few hours ----
		RowLayout {
			Layout.fillWidth: true
			Layout.leftMargin: 8
			Layout.rightMargin: 8
			spacing: 4

			visible: Weather.hourly.length > 0

			Repeater {
				model: Weather.hourly.slice(0, root.hoursShown)

				ColumnLayout {
					required property var modelData

					Layout.preferredWidth: root.hourColumnWidth
					Layout.maximumWidth: root.hourColumnWidth
					spacing: 3

					Label {
						Layout.alignment: Qt.AlignHCenter
						// "13", not "13:00" — the minutes are always zero and
						// they were what made the row unreadable.
						text: modelData.hour.slice(0, 2)
						color: Config.fgDim
						font.pixelSize: Config.fontSize - 1
					}

					Label {
						Layout.alignment: Qt.AlignHCenter
						text: Weather.iconFor(modelData.code)
						color: Config.accent
						font.pixelSize: Config.fontSize + 6
					}

					Label {
						Layout.alignment: Qt.AlignHCenter
						text: root.degrees(modelData.temp)
						font.pixelSize: Config.fontSize + 1
					}

					Label {
						Layout.alignment: Qt.AlignHCenter
						text: modelData.rain > 0 ? modelData.rain + "%" : " "
						color: Config.blue
						font.pixelSize: Config.fontSize - 3
					}
				}
			}
		}

		Rectangle {
			Layout.fillWidth: true
			Layout.topMargin: 2
			Layout.preferredHeight: 1
			visible: Weather.forecast.length > 0
			color: Config.border
		}

		// ---- the days ahead ----
		Repeater {
			model: Weather.forecast

			RowLayout {
				required property var modelData
				required property int index

				Layout.fillWidth: true
				Layout.leftMargin: 8
				Layout.rightMargin: 8
				Layout.preferredHeight: 26
				spacing: 10

				Label {
					Layout.preferredWidth: 54
					text: root.dayName(modelData.day, index)
					color: index === 0 ? Config.fg : Config.fgDim
					font.pixelSize: Config.fontSize + 1
				}

				Label {
					Layout.preferredWidth: 22
					text: Weather.iconFor(modelData.code)
					color: Config.fgDim
					font.pixelSize: Config.fontSize + 4
				}

				Label {
					Layout.fillWidth: true
					Layout.minimumWidth: 0
					text: Weather.describe(modelData.code)
					color: Config.fgDim
					font.pixelSize: Config.fontSize
					elide: Text.ElideRight
				}

				Label {
					Layout.preferredWidth: 42
					horizontalAlignment: Text.AlignRight
					text: modelData.rain > 0 ? modelData.rain + "%" : ""
					color: Config.blue
					font.pixelSize: Config.fontSize - 1
				}

				Label {
					Layout.preferredWidth: 40
					horizontalAlignment: Text.AlignRight
					text: root.degrees(modelData.max)
					font.pixelSize: Config.fontSize + 1
				}

				Label {
					Layout.preferredWidth: 36
					horizontalAlignment: Text.AlignRight
					text: root.degrees(modelData.min)
					color: Config.fgDim
					font.pixelSize: Config.fontSize + 1
				}
			}
		}
	}

	// One labelled number.
	component Stat: ColumnLayout {
		id: stat

		property string label
		property string value
		property color tint: Config.fg

		Layout.fillWidth: true
		spacing: 0

		Label {
			Layout.fillWidth: true
			text: stat.label
			color: Config.fgDim
			font.pixelSize: Config.fontSize - 2
			elide: Text.ElideRight
		}

		Label {
			Layout.fillWidth: true
			text: stat.value
			color: stat.tint
			font.pixelSize: Config.fontSize + 2
			elide: Text.ElideRight
		}
	}
}
