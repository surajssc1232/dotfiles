import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

PanelWindow {
    id: root

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 38        // ← bar height, change this

    // Gap from screen edges — gives the "floating corners" look
    margins.top:   4          // ← distance from top of screen, change this
    margins.left:  10         // ← distance from left edge
    margins.right: 10         // ← distance from right edge

    // Transparent so our rounded Rectangle shows through
    color: "transparent"

    // ── Font — run: fc-list | grep -i jetbrains  to find your exact name ──
    readonly property string f: "JetBrainsMono Nerd Font Mono"

    // ── Gruvbox palette ────────────────────────────────────────────────────
    readonly property color gbBg:     "#282828"
    readonly property color gbBg1:    "#3c3836"
    readonly property color gbBg2:    "#504945"
    readonly property color gbBg4:    "#7c6f64"
    readonly property color gbFg:     "#ebdbb2"
    readonly property color gbFg4:    "#a89984"
    readonly property color gbRed:    "#fb4934"
    readonly property color gbGreen:  "#b8bb26"
    readonly property color gbYellow: "#fabd2f"
    readonly property color gbBlue:   "#83a598"
    readonly property color gbPurple: "#d3869b"
    readonly property color gbAqua:   "#8ec07c"
    readonly property color gbOrange: "#fe8019"

    // ── Niri workspace state ───────────────────────────────────────────────
    property var workspaces: []

    Process {
        id: niriEvents
        command: ["niri", "msg", "-j", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    var event = JSON.parse(data)
                    if (event.WorkspacesChanged) {
                        root.workspaces = event.WorkspacesChanged.workspaces
                    }
                    if (event.WorkspaceActivated) {
                        var activatedId = event.WorkspaceActivated.id
                        var focused     = event.WorkspaceActivated.focused
                        root.workspaces = root.workspaces.map(ws =>
                            Object.assign({}, ws, {
                                is_focused: focused ? ws.id === activatedId : ws.is_focused
                            })
                        )
                    }
                } catch(e) {}
            }
        }
        onRunningChanged: { if (!running) restartTimer.start() }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: niriEvents.running = true
    }

    // ── System stats ───────────────────────────────────────────────────────
    property string cpuUsage:      "0%"
    property string ramUsage:      "0%"
    property string diskUsage:     "0%"
    property string batteryLevel:  ""
    property string batteryStatus: ""
    property string cpuTemp:       "0°C"
    property string ramUsed:       "0 GB"
    property string ramTotal:      "0 GB"
    property string diskUsed:      "0 GB"
    property string diskTotal:     "0 GB"

    property var prevCpuIdle:  0
    property var prevCpuTotal: 0

    // CPU — reads /proc/stat via sh, one line
    Process {
        id: cpuProc
        command: ["sh", "-c", "awk '/^cpu /{print; exit}' /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                var p    = data.trim().split(/\s+/)
                var user = parseInt(p[1]), nice   = parseInt(p[2]),
                    sys  = parseInt(p[3]), idle   = parseInt(p[4]),
                    io   = parseInt(p[5]), irq    = parseInt(p[6]),
                    sirq = parseInt(p[7])
                var total = user + nice + sys + idle + io + irq + sirq
                var td = total - root.prevCpuTotal
                var id = idle  - root.prevCpuIdle
                if (td > 0) root.cpuUsage = Math.round((1 - id / td) * 100) + "%"
                root.prevCpuTotal = total
                root.prevCpuIdle  = idle
            }
        }
    }

    // Disk + battery + temp — one process, multiple lines
    Process {
        id: statsProc
        command: [
            "sh", "-c",
            "df / | awk 'NR==2{print $5}'; " +
            "df / | awk 'NR==2{print $3,$2}'; " +
            "cat /sys/class/thermal/thermal_zone6/temp 2>/dev/null || cat /sys/class/thermal/thermal_zone7/temp 2>/dev/null || echo ''; " +
            "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo ''; " +
            "cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo ''"
        ]
        property int lineNum: 0
        stdout: SplitParser {
            onRead: data => {
                var val = data.trim()
                if      (statsProc.lineNum === 0) root.diskUsage = val
                else if (statsProc.lineNum === 1) {
                    var parts = val.split(" ")
                    if (parts.length >= 2) {
                        root.diskUsed  = Math.round(parseInt(parts[0]) / 1024 / 1024) + " GB"
                        root.diskTotal = Math.round(parseInt(parts[1]) / 1024 / 1024) + " GB"
                    }
                }
                else if (statsProc.lineNum === 2) root.cpuTemp = val !== "" ? Math.round(parseInt(val) / 1000) : ""
                else if (statsProc.lineNum === 3) root.batteryLevel = val !== "" ? val + "%" : ""
                else if (statsProc.lineNum === 4) root.batteryStatus = val
                statsProc.lineNum++
            }
        }
        onRunningChanged: { if (!running) lineNum = 0 }
    }

    // RAM — reads /proc/meminfo
    Process {
        id: ramProc
        command: ["sh", "-c", "awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf \"%d\\n%d\\n%d\", (t-a)*100/t, (t-a)/1024/1024, t/1024/1024}' /proc/meminfo"]
        property int lineNum: 0
        stdout: SplitParser {
            onRead: data => {
                var val = data.trim()
                if      (ramProc.lineNum === 0) root.ramUsage = val + "%"
                else if (ramProc.lineNum === 1) root.ramUsed = val + " GB"
                else if (ramProc.lineNum === 2) root.ramTotal = val + " GB"
                ramProc.lineNum++
            }
        }
        onRunningChanged: { if (!running) lineNum = 0 }
    }

    // Refresh all stats every 3 seconds
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            cpuProc.running   = true
            ramProc.running   = true
            statsProc.running = true
        }
        Component.onCompleted: triggered()
    }

    // ── Calendar state ─────────────────────────────────────────────────────
    property bool calendarVisible: false
    property bool calendarOpen:    false
    property var  calendarDate:    new Date()

    onCalendarOpenChanged: {
        if (calendarOpen) {
            calendarVisible = true
        } else {
            calendarHideTimer.start()
        }
    }

    Timer {
        id: calendarHideTimer
        interval: 220
        onTriggered: root.calendarVisible = false
    }

    // ── Bar layout ─────────────────────────────────────────────────────────
    // Rounded pill background — this is the visible bar
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: root.gbBg

        // Subtle border for definition
        border.color: root.gbBg2
        border.width: 1
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 0

        // LEFT — NixOS logo + workspaces
        RowLayout {
            spacing: 10

            Text {
                // Nerd Font NixOS glyph — replace with "❄" if not using Nerd Fonts
                text: "\uf313"
                color: root.gbBlue
                font.family: root.f
                font.pixelSize: 30
            }

            RowLayout {
                spacing: 6
                Repeater {
                    model: root.workspaces
                    Rectangle {
                        required property var modelData

                        width:  modelData.is_focused ? 22 : 8
                        height: 8
                        radius: 4

                        Behavior on width {
                            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                        }

                        color: modelData.is_focused ? root.gbYellow
                             : modelData.is_active  ? root.gbBg4
                             :                        root.gbBg2

                        opacity: modelData.output === (root.workspaces.find(w => w.is_focused)?.output ?? "")
                                 ? 1.0 : 0.5

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Qt.createQmlObject(
                                'import Quickshell.Io; Process { command: ["niri","msg","action","focus-workspace","--id","' + modelData.id + '"]; running: true }',
                                root, "wsSwitch"
                            )
                        }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        // CENTER — clock with hover highlight
        Item {
            implicitWidth:  clockText.implicitWidth + 16
            implicitHeight: parent.height

            Rectangle {
                anchors.centerIn: parent
                width:   clockText.implicitWidth + 16
                height:  22
                radius:  6
                color:   root.gbBg1
                opacity: clockHover.containsMouse ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            Text {
                id: clockText
                anchors.centerIn: parent
                color: root.gbFg
                font.family: root.f
                font.pixelSize: 13

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clockText.text = Qt.formatDateTime(new Date(), "ddd, MMM d   hh:mm")
                }
                Component.onCompleted: clockText.text = Qt.formatDateTime(new Date(), "ddd, MMM d   hh:mm")
            }

            MouseArea {
                id: clockHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.calendarOpen) root.calendarDate = new Date()
                    root.calendarOpen = !root.calendarOpen
                }
            }
        }

        Item { Layout.fillWidth: true }

        // RIGHT — stats
        RowLayout {
            spacing: 12

            // Combined CPU/RAM/DSK icon with popup
            Item {
                implicitWidth:  32
                implicitHeight: parent.height

                Rectangle {
                    anchors.centerIn: parent
                    width:   32
                    height:  22
                    radius:  6
                    color:   root.gbBg1
                    opacity: statsIconHover.containsMouse ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                Text {
                    id: statsIconText
                    anchors.centerIn: parent
                    text: "\uf2db"  // Single icon in bar
                    color: root.gbFg
                    font.family: root.f
                    font.pixelSize: 14
                }

                MouseArea {
                    id: statsIconHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.statsOpen = !root.statsOpen
                }
            }

            // Battery — shows even if level is unknown, hides only on desktops
            Rectangle {
                visible: root.batteryLevel !== ""
                height: 22
                width: batteryText.implicitWidth + 16
                radius: 6

                // Background pill changes color by state
                color: root.batteryStatus === "Charging"      ? Qt.rgba(0.18, 0.47, 0.18, 0.35)
                     : parseInt(root.batteryLevel) < 20       ? Qt.rgba(0.98, 0.29, 0.20, 0.35)
                     :                                          "transparent"

                // Border matches the fill color but fully opaque
                border.width: 1
                border.color: root.batteryStatus === "Charging"      ? root.gbGreen
                            : parseInt(root.batteryLevel) < 20       ? root.gbRed
                            :                                          root.gbBg2

                Text {
                    id: batteryText
                    anchors.centerIn: parent
                    font.family: root.f
                    font.pixelSize: 13

                    // Icon reflects charging state and level
                    property string icon: {
                        if (root.batteryStatus === "Charging")        return "\uf1e6 "   // plug icon
                        var n = parseInt(root.batteryLevel)
                        if (n < 10)  return "\uf244 "   // empty battery
                        if (n < 30)  return "\uf243 "   // quarter
                        if (n < 60)  return "\uf242 "   // half
                        if (n < 85)  return "\uf241 "   // three quarter
                        return "\uf240 "                // full
                    }

                    text: icon + root.batteryLevel
                    color: root.batteryStatus === "Charging" ? root.gbGreen
                         : parseInt(root.batteryLevel) < 20  ? root.gbRed
                         :                                     root.gbAqua
                }
            }        }
    }

    // ── Stats popup state ───────────────────────────────────────────────────
    property bool statsVisible: false
    property bool statsOpen:    false

    onStatsOpenChanged: {
        if (statsOpen) {
            statsVisible = true
        } else {
            statsHideTimer.start()
        }
    }

    Timer {
        id: statsHideTimer
        interval: 220
        onTriggered: root.statsVisible = false
    }

    // ── Calendar popup ─────────────────────────────────────────────────────
    PopupWindow {
        id: calendarPopup
        visible: root.calendarVisible
        implicitWidth:  268
        implicitHeight: 252

        anchor.window:  root
        anchor.rect.x:  (root.width / 2) - (implicitWidth / 2)
        // implicitHeight (48) + top margin (8) = 56, places popup just below the bar
        anchor.rect.y:  root.implicitHeight + 8

        // Transparent so our rounded Rectangle shows through
        color: "transparent"

        Item {
            id: calInner
            anchors.fill: parent
            opacity: 0
            scale:   0.92
            transformOrigin: Item.Top

            // Rounded background for the calendar
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: root.gbBg1
                border.color: root.gbBg2
                border.width: 1
            }

            states: [
                State {
                    name: "open"
                    when: root.calendarOpen
                    PropertyChanges { target: calInner; opacity: 1.0; scale: 1.0 }
                }
            ]

            transitions: [
                Transition {
                    to: "open"
                    ParallelAnimation {
                        NumberAnimation {
                            target: calInner; property: "opacity"
                            from: 0.0; to: 1.0
                            duration: 200; easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: calInner; property: "scale"
                            from: 0.92; to: 1.0
                            duration: 200; easing.type: Easing.OutCubic
                        }
                    }
                },
                Transition {
                    from: "open"
                    ParallelAnimation {
                        NumberAnimation {
                            target: calInner; property: "opacity"
                            from: 1.0; to: 0.0
                            duration: 180; easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            target: calInner; property: "scale"
                            from: 1.0; to: 0.92
                            duration: 180; easing.type: Easing.InCubic
                        }
                    }
                }
            ]

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    width: parent.width

                    Text {
                        text: "‹"
                        color: root.gbFg4
                        font.family: root.f
                        font.pixelSize: 18
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.calendarDate = new Date(root.calendarDate.getFullYear(), root.calendarDate.getMonth() - 1, 1)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Qt.formatDateTime(root.calendarDate, "MMMM yyyy")
                        color: root.gbYellow
                        font.family: root.f
                        font.pixelSize: 13
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        text: "›"
                        color: root.gbFg4
                        font.family: root.f
                        font.pixelSize: 18
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.calendarDate = new Date(root.calendarDate.getFullYear(), root.calendarDate.getMonth() + 1, 1)
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0
                    Repeater {
                        model: ["Su","Mo","Tu","We","Th","Fr","Sa"]
                        Text {
                            required property string modelData
                            text: modelData
                            color: root.gbBg4
                            font.family: root.f
                            font.pixelSize: 11
                            width: 34
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                Grid {
                    id: calGrid
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 7
                    spacing: 2

                    property var  today:        new Date()
                    property var  displayMonth: root.calendarDate
                    property int  firstWeekday: new Date(displayMonth.getFullYear(), displayMonth.getMonth(), 1).getDay()
                    property int  daysInMonth:  new Date(displayMonth.getFullYear(), displayMonth.getMonth() + 1, 0).getDate()
                    property bool isCurrentMonth: today.getFullYear() === displayMonth.getFullYear()
                                               && today.getMonth()    === displayMonth.getMonth()

                    Repeater {
                        model: 42
                        delegate: Item {
                            required property int index
                            width: 34; height: 26

                            property int  dayNum:  index - calGrid.firstWeekday + 1
                            property bool inMonth: dayNum >= 1 && dayNum <= calGrid.daysInMonth
                            property bool isToday: calGrid.isCurrentMonth && dayNum === calGrid.today.getDate()

                            Rectangle {
                                visible: isToday
                                anchors.centerIn: parent
                                width: 24; height: 24; radius: 12
                                color: root.gbBg2
                                border.color: root.gbYellow
                                border.width: 1
                            }

                            Text {
                                anchors.centerIn: parent
                                text: inMonth ? dayNum : ""
                                color: isToday ? root.gbYellow : root.gbFg
                                font.family: root.f
                                font.pixelSize: 11
                                font.bold: isToday
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.calendarOpen = false
                propagateComposedEvents: true
                onPressed: mouse => mouse.accepted = false
            }
        }
    }

    // ── Stats popup ────────────────────────────────────────────────────────
    PopupWindow {
        id: statsPopup
        visible: root.statsVisible
        implicitWidth:  260
        implicitHeight: 180

        anchor.window:  root
        anchor.rect.x:  root.width - implicitWidth - 14
        anchor.rect.y:  root.implicitHeight + 8

        color: "transparent"

        Item {
            id: statsInner
            anchors.fill: parent
            opacity: 0
            scale:   0.92
            transformOrigin: Item.Top

            Rectangle {
                anchors.fill: parent
                radius: 12
                color: root.gbBg1
                border.color: root.gbBg2
                border.width: 1
            }

            states: [
                State {
                    name: "open"
                    when: root.statsOpen
                    PropertyChanges { target: statsInner; opacity: 1.0; scale: 1.0 }
                }
            ]

            transitions: [
                Transition {
                    to: "open"
                    ParallelAnimation {
                        NumberAnimation { target: statsInner; property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                        NumberAnimation { target: statsInner; property: "scale"; from: 0.92; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                    }
                },
                Transition {
                    from: "open"
                    ParallelAnimation {
                        NumberAnimation { target: statsInner; property: "opacity"; from: 1.0; to: 0.0; duration: 180; easing.type: Easing.InCubic }
                        NumberAnimation { target: statsInner; property: "scale"; from: 1.0; to: 0.92; duration: 180; easing.type: Easing.InCubic }
                    }
                }
            ]

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // CPU
                RowLayout {
                    width: parent.width

                    Text {
                        text: "\uf2db"
                        color: {
                            var n = parseInt(root.cpuUsage)
                            return n > 80 ? root.gbRed : n > 50 ? root.gbOrange : root.gbGreen
                        }
                        font.family: root.f
                        font.pixelSize: 14
                    }

                    Text {
                        text: "CPU"
                        color: root.gbFg4
                        font.family: root.f
                        font.pixelSize: 12
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        Text {
                            text: root.cpuUsage
                            color: {
                                var n = parseInt(root.cpuUsage)
                                return n > 80 ? root.gbRed : n > 50 ? root.gbOrange : root.gbGreen
                            }
                            font.family: root.f
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Text {
                            text: root.cpuTemp ? root.cpuTemp + "°" : ""
                            color: root.gbFg4
                            font.family: root.f
                            font.pixelSize: 11
                        }
                    }
                }

                // RAM
                RowLayout {
                    width: parent.width

                    Text {
                        text: "\ue85a"
                        color: {
                            var n = parseInt(root.ramUsage)
                            return n > 80 ? root.gbRed : root.gbYellow
                        }
                        font.family: root.f
                        font.pixelSize: 14
                    }

                    Text {
                        text: "RAM"
                        color: root.gbFg4
                        font.family: root.f
                        font.pixelSize: 12
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        Text {
                            text: root.ramUsage
                            color: {
                                var n = parseInt(root.ramUsage)
                                return n > 80 ? root.gbRed : root.gbYellow
                            }
                            font.family: root.f
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Text {
                            text: root.ramUsed ? root.ramUsed + " / " + root.ramTotal + " GB" : ""
                            color: root.gbFg4
                            font.family: root.f
                            font.pixelSize: 11
                        }
                    }
                }

                // Disk
                RowLayout {
                    width: parent.width

                    Text {
                        text: "\uf0b6"
                        color: root.gbPurple
                        font.family: root.f
                        font.pixelSize: 14
                    }

                    Text {
                        text: "DSK"
                        color: root.gbFg4
                        font.family: root.f
                        font.pixelSize: 12
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        Text {
                            text: root.diskUsage
                            color: root.gbPurple
                            font.family: root.f
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Text {
                            text: root.diskUsed ? root.diskUsed + " / " + root.diskTotal + " GB" : ""
                            color: root.gbFg4
                            font.family: root.f
                            font.pixelSize: 11
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.statsOpen = false
                propagateComposedEvents: true
                onPressed: mouse => mouse.accepted = false
            }
        }
    }

    Loader {
    source: "NotificationToast.qml"
}
}
