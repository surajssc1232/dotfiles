import QtQuick
import qs

// A volume slider for the mixer: drag or click anywhere on it, scroll for 5%
// steps that land on round numbers. With `max` above 1 the track runs past
// 100%, marked with a tick, for apps or devices that are simply too quiet.
// An optional level meter under the track shows what is actually playing.
Item {
	id: root

	property real value: 0       // 0..max
	property real max: 1
	property bool muted: false
	property color tone: Config.accent
	// Live level 0..1, or below 0 for no meter.
	property real peak: -1

	property real step: 0.05

	signal moved(real value)

	implicitHeight: 22
	implicitWidth: 160

	readonly property real frac: Math.max(0, Math.min(1, root.value / root.max))
	readonly property color ink: root.muted ? Config.fgDim : root.tone

	function commit(x: real) {
		const v = Math.max(0, Math.min(1, (x - knob.width / 2) / (width - knob.width))) * root.max;
		// Sticks to 100% on the way past, so a boosted track is easy to bring
		// back to exactly full.
		root.moved(root.max > 1 && Math.abs(v - 1) < 0.03 ? 1 : v);
	}

	MouseArea {
		anchors.fill: parent
		preventStealing: true
		cursorShape: Qt.PointingHandCursor

		onPressed: event => root.commit(event.x)
		onPositionChanged: event => { if (pressed) root.commit(event.x); }

		onWheel: event => {
			const dir = event.angleDelta.y > 0 ? 1 : event.angleDelta.y < 0 ? -1 : 0;
			if (dir === 0) return;
			const next = Math.round((root.value + dir * root.step) / root.step) * root.step;
			root.moved(Math.max(0, Math.min(root.max, next)));
		}
	}

	// ---- track ----
	Rectangle {
		id: track

		anchors.verticalCenter: parent.verticalCenter
		anchors.verticalCenterOffset: root.peak >= 0 ? -3 : 0
		x: knob.width / 2
		width: parent.width - knob.width
		height: 6
		radius: 3
		color: Config.bgAlt

		Rectangle {
			width: parent.width * root.frac
			height: parent.height
			radius: 3
			color: root.ink
			opacity: root.muted ? 0.5 : 1

			Behavior on width { NumberAnimation { duration: 80 } }
		}

		// Where 100% is, once the track goes past it.
		Rectangle {
			visible: root.max > 1
			x: parent.width / root.max - 1
			anchors.verticalCenter: parent.verticalCenter
			width: 2
			height: 12
			radius: 1
			color: Config.fgDim
			opacity: 0.8
		}
	}

	// ---- level meter ----
	// Fast up, slow down, the way a VU meter reads.
	Rectangle {
		visible: root.peak >= 0
		anchors.top: track.bottom
		anchors.topMargin: 4
		x: track.x
		width: track.width
		height: 3
		radius: 1.5
		color: Qt.alpha(Config.fg, 0.08)

		Rectangle {
			id: level

			property real shown: 0

			width: parent.width * Math.min(1, shown)
			height: parent.height
			radius: 1.5
			color: shown > 0.9 ? Config.red : shown > 0.7 ? Config.yellow : Config.green
			opacity: root.muted ? 0.3 : 0.9

			Connections {
				target: root
				function onPeakChanged() {
					const p = root.muted ? 0 : Math.max(0, root.peak);
					level.shown = p > level.shown ? p : level.shown * 0.82 + p * 0.18;
				}
			}
		}
	}

	// ---- knob ----
	Rectangle {
		id: knob

		x: root.frac * (root.width - width)
		anchors.verticalCenter: track.verticalCenter
		width: 14
		height: 14
		radius: 7
		color: Config.surface
		border.width: 2
		border.color: root.ink

		Behavior on x { NumberAnimation { duration: 80 } }
	}
}
