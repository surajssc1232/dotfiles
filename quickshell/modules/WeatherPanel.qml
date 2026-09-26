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
		RowLayout {
			Layout.fillWidth: true
			Layout.leftMargin: 8
			Layout.rightMargin: 8
			Layout.topMargin: 2

			visible: Weather.valid
			spacing: 20

		WindCompass {
			Layout.alignment: Qt.AlignTop
		}

		// Sized to its contents and centred between the two dials by the
		// spacers either side; stretched, it would push all its spare width
		// to the right of left-aligned text and sit visibly off-centre.
		Item { Layout.fillWidth: true }

		GridLayout {
			Layout.alignment: Qt.AlignVCenter

			columns: 2
			rowSpacing: 12
			columnSpacing: 36

			Stat {
				label: "Feels like"
				value: root.degrees(Weather.feelsLike)
			}

			Stat {
				label: "Humidity"
				value: Weather.humidity + "%"
			}

			Stat {
				label: "Rain"
				value: Weather.rainChance + "% · " + Weather.precipitation.toFixed(1) + " mm"
				tint: Weather.rainChance >= 60 ? Config.blue : Config.fg
			}

			Stat {
				label: "UV index"
				value: Weather.uvMax.toFixed(1)
				tint: Weather.uvMax >= 8 ? Config.red
					: Weather.uvMax >= 6 ? Config.yellow : Config.fg
			}

			Stat {
				label: "Sunrise"
				value: Weather.sunrise
			}

			Stat {
				label: "Sunset"
				value: Weather.sunset
			}

		}

		Item { Layout.fillWidth: true }

		AirGauge {
			Layout.alignment: Qt.AlignTop
			visible: Weather.airValid
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

				// The day's worst air, from the air-quality forecast. That
				// runs a day or two shorter than the weather, so the last
				// rows may have none.
				AirChip {
					Layout.fillWidth: false
					Layout.minimumWidth: 52
					Layout.maximumWidth: 52
					value: Weather.airDays.find(d => d.day === modelData.day)?.max ?? -1
				}

				Label {
					Layout.preferredWidth: 42
					horizontalAlignment: Text.AlignRight
					// 0% still printed, dimmed, so a dry day reads as dry
					// rather than as a gap where a number failed to load.
					text: modelData.rain + "%"
					color: modelData.rain > 0 ? Config.blue : Config.fgDim
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

	// Today's air as a half-dial: one segment per AQI band, a needle at the
	// current reading, and the number and its band underneath.
	//
	// The bands are drawn equal-width even though they are not equal in
	// value (Good is 50 wide, Hazardous 200), the way printed AQI dials do
	// it: on a to-scale dial the two bands anyone actually sees most would
	// share the first fifth of the arc.
	component AirGauge: ColumnLayout {
		id: gauge

		readonly property int dialWidth: 176
		readonly property int dialHeight: 100
		readonly property real radius: 62
		readonly property real thickness: 14
		// Centre of the arc, low enough to leave room for the hub.
		readonly property real cx: dialWidth / 2
		readonly property real cy: dialHeight - 12

		// 0..1 along the arc for an AQI value, band by band.
		function fraction(value: real): real {
			const bands = Weather.airBands;
			let lo = 0;
			for (let i = 0; i < bands.length; i++) {
				if (value <= bands[i].upTo || i === bands.length - 1) {
					const within = Math.max(0, Math.min(1, (value - lo) / (bands[i].upTo - lo)));
					return (i + within) / bands.length;
				}
				lo = bands[i].upTo;
			}
			return 1;
		}

		spacing: 4

		RowLayout {
			spacing: 6

			Label {
				text: Config.icons.leaf ?? ""
				visible: text !== ""
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 3
			}

			Label {
				text: "AIR QUALITY"
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 3
				font.letterSpacing: 1
			}
		}

		Item {
			Layout.preferredWidth: gauge.dialWidth
			Layout.preferredHeight: gauge.dialHeight

			Canvas {
				id: dial

				anchors.fill: parent

				property color hand: Config.fg
				property color hole: Config.bg
				property real value: Weather.aqi

				onHandChanged: requestPaint()
				onHoleChanged: requestPaint()
				onValueChanged: requestPaint()

				onPaint: {
					const ctx = getContext("2d");
					ctx.reset();

					// Canvas angles run clockwise from +x, so the top half
					// of a circle is π (left) through 2π (right).
					const bands = Weather.airBands;
					const step = Math.PI / bands.length;
					const gap = 0.025;
					ctx.lineWidth = gauge.thickness;
					ctx.lineCap = "butt";
					for (let i = 0; i < bands.length; i++) {
						ctx.strokeStyle = bands[i].color;
						ctx.beginPath();
						ctx.arc(gauge.cx, gauge.cy, gauge.radius,
							Math.PI + i * step + gap, Math.PI + (i + 1) * step - gap, false);
						ctx.stroke();
					}

					// Needle: a long thin triangle from the hub.
					const a = Math.PI + gauge.fraction(dial.value) * Math.PI;
					const ux = Math.cos(a);
					const uy = Math.sin(a);
					const px = -uy;
					const py = ux;
					const length = gauge.radius - gauge.thickness / 2 - 6;
					const base = 6;

					ctx.fillStyle = dial.hand;
					ctx.beginPath();
					ctx.moveTo(gauge.cx + ux * length, gauge.cy + uy * length);
					ctx.lineTo(gauge.cx + px * base, gauge.cy + py * base);
					ctx.lineTo(gauge.cx - px * base, gauge.cy - py * base);
					ctx.closePath();
					ctx.fill();

					// Hub, with a hole punched in it.
					ctx.beginPath();
					ctx.arc(gauge.cx, gauge.cy, 8, 0, Math.PI * 2);
					ctx.fill();
					ctx.fillStyle = dial.hole;
					ctx.beginPath();
					ctx.arc(gauge.cx, gauge.cy, 3.5, 0, Math.PI * 2);
					ctx.fill();
				}
			}

			// The band edges, just outside the arc.
			Repeater {
				model: [0].concat(Weather.airBands.map(band => band.upTo))

				Label {
					required property int modelData
					required property int index

					readonly property real angle:
						Math.PI + index / Weather.airBands.length * Math.PI
					readonly property real reach: gauge.radius + gauge.thickness / 2 + 9

					x: gauge.cx + Math.cos(angle) * reach - width / 2
					y: gauge.cy + Math.sin(angle) * reach - height / 2
					text: modelData
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 5
				}
			}
		}

		Label {
			Layout.alignment: Qt.AlignHCenter
			text: Weather.aqi
			color: Weather.airBand(Weather.aqi).color
			font.pixelSize: Config.fontSize + 6
			font.weight: Font.DemiBold
		}

		Label {
			Layout.alignment: Qt.AlignHCenter
			Layout.maximumWidth: gauge.dialWidth
			text: Weather.airBand(Weather.aqi).text
			color: Config.fgDim
			font.pixelSize: Config.fontSize - 3
			elide: Text.ElideRight
		}
	}

	// An AQI reading as a coloured dot and number. Below zero means the
	// air-quality forecast does not reach that day, shown as a dim dash.
	// A fixed width, set by the row, keeps every chip in the same column;
	// a layout that is allowed to stretch would trade width with the
	// description beside it and land somewhere different on every row.
	component AirChip: RowLayout {
		id: chip

		property int value: -1

		spacing: 5

		Rectangle {
			Layout.preferredWidth: 7
			Layout.preferredHeight: 7
			radius: 3.5
			visible: chip.value >= 0
			color: Weather.airBand(chip.value).color
		}

		Label {
			Layout.leftMargin: chip.value >= 0 ? 0 : 12
			text: chip.value >= 0 ? chip.value : "—"
			color: chip.value >= 0 ? Weather.airBand(chip.value).color : Config.fgDim
			font.pixelSize: Config.fontSize - 1
		}
	}

	// Wind as a compass: speed in the middle, and an arrow running from the
	// side the wind comes from (the dot) to the side it blows toward (the
	// head). The arrow is split around the middle so it never runs through
	// the number.
	component WindCompass: ColumnLayout {
		id: wind

		readonly property int dial: 132

		spacing: 6

		RowLayout {
			spacing: 6

			Label {
				text: Config.icons.wind ?? ""
				visible: text !== ""
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 3
			}

			Label {
				text: "WIND"
				color: Config.fgDim
				font.pixelSize: Config.fontSize - 3
				font.letterSpacing: 1
			}
		}

		Item {
			Layout.preferredWidth: wind.dial
			Layout.preferredHeight: wind.dial

			Canvas {
				id: face

				anchors.fill: parent

				property color tick: Config.fgDim
				property color hand: Config.fg
				property real direction: Weather.windDirection

				onTickChanged: requestPaint()
				onHandChanged: requestPaint()
				onDirectionChanged: requestPaint()

				onPaint: {
					const ctx = getContext("2d");
					const c = width / 2;
					const outer = c - 1;
					ctx.reset();

					// 60 ticks, heavier every 30 degrees. Left out where the
					// four letters sit, so they read against a gap.
					for (let i = 0; i < 60; i++) {
						if (i % 15 === 0) continue;
						const a = i * Math.PI / 30;
						const major = i % 5 === 0;
						const inner = outer - (major ? 9 : 6);
						ctx.globalAlpha = major ? 0.9 : 0.45;
						ctx.strokeStyle = face.tick;
						ctx.lineWidth = major ? 1.5 : 1;
						ctx.beginPath();
						ctx.moveTo(c + Math.sin(a) * inner, c - Math.cos(a) * inner);
						ctx.lineTo(c + Math.sin(a) * outer, c - Math.cos(a) * outer);
						ctx.stroke();
					}

					ctx.globalAlpha = 1;
					ctx.strokeStyle = face.hand;
					ctx.fillStyle = face.hand;
					ctx.lineWidth = 2.5;
					ctx.lineCap = "round";

					// Compass bearings run clockwise from north; the canvas's
					// y axis runs down, hence the minus on cos.
					const from = face.direction * Math.PI / 180;
					const ux = Math.sin(from);
					const uy = -Math.cos(from);
					const reach = outer - 14;
					const gap = 24;

					// Tail: from the rim, with a dot, into the middle.
					ctx.beginPath();
					ctx.moveTo(c + ux * reach, c + uy * reach);
					ctx.lineTo(c + ux * gap, c + uy * gap);
					ctx.stroke();
					ctx.beginPath();
					ctx.arc(c + ux * reach, c + uy * reach, 4, 0, Math.PI * 2);
					ctx.fill();

					// Head: out of the middle to the opposite rim.
					const tipX = c - ux * reach;
					const tipY = c - uy * reach;
					ctx.beginPath();
					ctx.moveTo(c - ux * gap, c - uy * gap);
					ctx.lineTo(tipX, tipY);
					ctx.stroke();

					// Arrowhead, folded back from the tip along the shaft.
					const px = -uy;
					const py = ux;
					ctx.beginPath();
					ctx.moveTo(tipX, tipY);
					ctx.lineTo(tipX + ux * 9 + px * 5, tipY + uy * 9 + py * 5);
					ctx.lineTo(tipX + ux * 9 - px * 5, tipY + uy * 9 - py * 5);
					ctx.closePath();
					ctx.fill();
				}
			}

			Repeater {
				model: ["N", "E", "S", "W"]

				Label {
					required property string modelData
					required property int index

					readonly property real angle: index * Math.PI / 2
					readonly property real radius: wind.dial / 2 - 7

					x: wind.dial / 2 + Math.sin(angle) * radius - width / 2
					y: wind.dial / 2 - Math.cos(angle) * radius - height / 2
					text: modelData
					color: Config.fg
					font.pixelSize: Config.fontSize - 3
					font.weight: Font.DemiBold
				}
			}

			ColumnLayout {
				anchors.centerIn: parent
				spacing: -2

				Label {
					Layout.alignment: Qt.AlignHCenter
					text: Math.round(Weather.wind)
					font.pixelSize: Config.fontSize + 6
					font.weight: Font.DemiBold
				}

				Label {
					Layout.alignment: Qt.AlignHCenter
					text: "km/h"
					color: Config.fgDim
					font.pixelSize: Config.fontSize - 4
				}
			}
		}

		Label {
			Layout.alignment: Qt.AlignHCenter
			text: "Gusts: " + Math.round(Weather.gusts) + " km/h "
				+ Weather.bearing(Weather.windDirection)
			color: Config.fgDim
			font.pixelSize: Config.fontSize - 3
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
