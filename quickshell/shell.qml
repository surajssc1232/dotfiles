import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris

ShellRoot {
    id: shell
    
    property var workspaces: []

    

    // ── Pipewire volume tracking ───────────────────────────────────────────────
    PwObjectTracker {
        objects: [ Pipewire.defaultAudioSink ]
    }

    Process {
        id: niriEvents
        command: ["niri", "msg", "-j", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    var event = JSON.parse(data)
                    if (event.WorkspacesChanged) {
                        shell.workspaces = event.WorkspacesChanged.workspaces
                    }
                    if (event.WorkspaceActivated) {
                        var activatedId = event.WorkspaceActivated.id
                        var focused     = event.WorkspaceActivated.focused
                        shell.workspaces = shell.workspaces.map(ws =>
                            Object.assign({}, ws, {
                                is_focused: focused ? ws.id === activatedId : ws.is_focused
                            })
                        )
                    }
                } catch(e) {}
            }
        }
        onRunningChanged: { if (!running) niriRestartTimer.start() }
    }

    Timer {
        id: niriRestartTimer
        interval: 2000
        onTriggered: niriEvents.running = true
    }

     


    // ── System stats shared across all bars ───────────────────────────────────
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
                var td = total - shell.prevCpuTotal
                var id = idle  - shell.prevCpuIdle
                if (td > 0) shell.cpuUsage = Math.round((1 - id / td) * 100) + "%"
                shell.prevCpuTotal = total
                shell.prevCpuIdle  = idle
            }
        }
    }

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
                if      (statsProc.lineNum === 0) shell.diskUsage = val
                else if (statsProc.lineNum === 1) {
                    var parts = val.split(" ")
                    if (parts.length >= 2) {
                        shell.diskUsed  = Math.round(parseInt(parts[0]) / 1024 / 1024) + " GB"
                        shell.diskTotal = Math.round(parseInt(parts[1]) / 1024 / 1024) + " GB"
                    }
                }
                else if (statsProc.lineNum === 2) shell.cpuTemp = val !== "" ? Math.round(parseInt(val) / 1000) : ""
                else if (statsProc.lineNum === 3) shell.batteryLevel = val !== "" ? val + "%" : ""
                else if (statsProc.lineNum === 4) shell.batteryStatus = val
                statsProc.lineNum++
            }
        }
        onRunningChanged: { if (!running) lineNum = 0 }
    }

    Process {
        id: ramProc
        command: ["sh", "-c", "awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf \"%d\\n%d\\n%d\", (t-a)*100/t, (t-a)/1024/1024, t/1024/1024}' /proc/meminfo"]
        property int lineNum: 0
        stdout: SplitParser {
            onRead: data => {
                var val = data.trim()
                if      (ramProc.lineNum === 0) shell.ramUsage = val + "%"
                else if (ramProc.lineNum === 1) shell.ramUsed = val + " GB"
                else if (ramProc.lineNum === 2) shell.ramTotal = val + " GB"
                ramProc.lineNum++
            }
        }
        onRunningChanged: { if (!running) lineNum = 0 }
    }

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

    // ── One bar per connected screen ──────────────────────────────────────────
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: root
            property var modelData

            screen: modelData

            anchors.top: true
            anchors.left: true
            anchors.right: true
            implicitHeight: 38

            margins.top:   4
            margins.left:  10
            margins.right: 10

            color: "transparent"

            // ── Font ──────────────────────────────────────────────────────────
            readonly property string f: "JetBrainsMono Nerd Font Mono"

            // ── Gruvbox palette ───────────────────────────────────────────────
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

            // ── Calendar state ────────────────────────────────────────────────
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

            
            Timer {
                    id: mprisHideTimer
                    interval: 220
                    onTriggered: root.mprisVisible = false
                }

            // ── ADD THIS NEW TIMER HERE ─────────────────────────────────────
            Timer {
                id: mprisKeepOpenTimer
                interval: 300
                onTriggered: {
                    // Close if not hovering widget AND not hovering popup
                    if (!mprisBarHover.containsMouse && !mprisPopup.anyHovered) {
                        root.mprisOpen = false
                    }
                }
            }
            // ── MPRIS popup containsMouse property ─────────────────────────
            property bool mprisPopupContainsMouse: false

            // ── Stats popup state ─────────────────────────────────────────────
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

            // ── Volume popup state ────────────────────────────────────────────
            property bool volumeVisible: false
            property bool volumeOpen:    false
            property var  audioSinks:    []
            property string defaultSinkName: ""

            onVolumeOpenChanged: {
                if (volumeOpen) {
                    volumeVisible = true
                    audioSinkPollProc.running = true
                } else {
                    volumeHideTimer.start()
                }
            }

            Timer {
                id: volumeHideTimer
                interval: 220
                onTriggered: root.volumeVisible = false
            }

            // Poll sinks on open
            Process {
                id: audioSinkPollProc
                command: ["sh", "-c",
                    "pactl list sinks short; echo '---'; pactl get-default-sink"
                ]
                property bool parsingDefault: false
                property var  parsedSinks: []
                stdout: SplitParser {
                    onRead: data => {
                        var line = data.trim()
                        if (line === "---") { audioSinkPollProc.parsingDefault = true; return }
                        if (audioSinkPollProc.parsingDefault) {
                            root.defaultSinkName = line
                            audioSinkPollProc.parsingDefault = false
                            return
                        }
                        var parts = line.split("\t")
                        if (parts.length >= 2) audioSinkPollProc.parsedSinks.push(parts[1])
                    }
                }
                onRunningChanged: {
                    if (!running) {
                        root.audioSinks = audioSinkPollProc.parsedSinks.slice()
                        audioSinkPollProc.parsedSinks = []
                        audioSinkPollProc.parsingDefault = false
                    } else {
                        audioSinkPollProc.parsedSinks = []
                        audioSinkPollProc.parsingDefault = false
                    }
                }
            }

            // Switch default sink and move all streams
            Process {
                id: audioSinkSetProc
                property string targetSink: ""
                command: ["sh", "-c",
                    "pactl set-default-sink \"" + audioSinkSetProc.targetSink + "\" && " +
                    "pactl list sink-inputs short | awk '{print $1}' | " +
                    "xargs -I{} pactl move-sink-input {} \"" + audioSinkSetProc.targetSink + "\""
                ]
                onRunningChanged: {
                    if (!running) {
                        root.defaultSinkName = audioSinkSetProc.targetSink
                        audioSinkPollProc.running = true
                    }
                }
            }

            // ── Brightness popup state ────────────────────────────────────────
            property bool brightnessVisible: false
            property bool brightnessOpen:    false
            property real brightnessLevel:   0.5

            onBrightnessOpenChanged: {
                if (brightnessOpen) brightnessVisible = true
                else brightnessHideTimer.start()
            }
           
            Timer {
                id: brightnessHideTimer
                interval: 220
                onTriggered: root.brightnessVisible = false
            }

            // ── Power popup state ─────────────────────────────────────────────
            property bool powerVisible: false
            property bool powerOpen:    false

            onPowerOpenChanged: {
                if(powerOpen) {
                    powerVisible = true
                    powerAutoCloseTimer.restart()
                }
                else{
                    powerHideTimer.stop()
                    powerAutoCloseTimer.stop()
                    powerHideTimer.start()
                }
            }

            Timer {
                id: powerHideTimer
                interval: 220
                onTriggered: root.powerVisible = false
            }

            Timer{
                id: powerAutoCloseTimer
                interval: 5000
                onTriggered: root.powerOpen = false
            }


                        // ── Control center state ──────────────────────────────────────────
            property bool ccVisible: false
            property bool ccOpen:    false

            onCcOpenChanged: {
                if (ccOpen) {
                    ccVisible = true
                    ccWallpaperProc.running = true
                    ccNetworkProc.running   = true
                    ccBluetoothProc.running = true
                } else {
                    ccHideTimer.start()
                }
            }

            Timer {
                id: ccHideTimer
                interval: 220
                onTriggered: root.ccVisible = false
            }

            // Wallpaper list
            property var   ccWallpapers:    []
            property string ccActiveWall:   ""
            property string ccWallpaperDir: Qt.resolvedUrl("").toString().replace("file://","").replace(/\/[^\/]*$/, "") // fallback
            property string wallpaperPath:  ""

            Process {
                id: ccWallpaperProc
                command: ["sh", "-c",
                    "ls ~/wallpapers/*.{jpg,jpeg,png,gif,webp} 2>/dev/null | head -40"
                ]
                property var parsed: []
                stdout: SplitParser {
                    onRead: data => {
                        var f = data.trim()
                        if (f !== "") ccWallpaperProc.parsed.push(f)
                    }
                }
                onRunningChanged: {
                    if (!running) {
                        root.ccWallpapers = ccWallpaperProc.parsed.slice()
                        ccWallpaperProc.parsed = []
                    } else {
                        ccWallpaperProc.parsed = []
                    }
                }
            }

            // Network info
            property string ccNetworkName:   "–"
            property string ccNetworkSignal: ""

            Process {
                id: ccNetworkProc
                command: ["sh", "-c",
                    "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 | head -1; " +
                    "nmcli -t -f active,signal dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 | head -1"
                ]
                property int lineNum: 0
                stdout: SplitParser {
                    onRead: data => {
                        var v = data.trim()
                        if (ccNetworkProc.lineNum === 0) root.ccNetworkName   = v !== "" ? v : "Not connected"
                        if (ccNetworkProc.lineNum === 1) root.ccNetworkSignal = v !== "" ? v + "%" : ""
                        ccNetworkProc.lineNum++
                    }
                }
                onRunningChanged: { if (!running) lineNum = 0; else lineNum = 0 }
            }

            // Bluetooth
            property string ccBluetoothStatus: "off"
            property var    ccBluetoothDevices: []

            Process {
                id: ccBluetoothProc
                command: ["sh", "-c",
                    "bluetoothctl show 2>/dev/null | grep -i 'powered' | awk '{print $2}'; " +
                    "bluetoothctl devices Connected 2>/dev/null | sed 's/Device [^ ]* //'"
                ]
                property bool firstLine: true
                property var  devsParsed: []
                stdout: SplitParser {
                    onRead: data => {
                        var v = data.trim()
                        if (ccBluetoothProc.firstLine) {
                            root.ccBluetoothStatus = v.toLowerCase() === "yes" ? "on" : "off"
                            ccBluetoothProc.firstLine = false
                        } else if (v !== "") {
                            ccBluetoothProc.devsParsed.push(v)
                        }
                    }
                }
                onRunningChanged: {
                    if (!running) {
                        root.ccBluetoothDevices = ccBluetoothProc.devsParsed.slice()
                        ccBluetoothProc.devsParsed = []
                        ccBluetoothProc.firstLine = true
                    } else {
                        ccBluetoothProc.devsParsed = []
                        ccBluetoothProc.firstLine = true
                    }
                }
            }

            // Quick toggles state
            property bool ccNightLight: false
            property bool ccDoNotDisturb: false

            // night light + swaybg are fired via Quickshell.execDetached() inline
            // Process.command is a static binding evaluated at object creation —
            // changing a property after the fact does NOT rebuild the command.
            

            // ── MPRIS popup state ─────────────────────────────────────────────
            property bool mprisVisible: false
            property bool mprisOpen:    false
            // Track the active player index ourselves
            property int  mprisPlayerIndex: 0
            // .values is the reactive list; [idx] works for binding updates
            readonly property var mprisPlayer: {
                var vals = Mpris.players.values
                if (!vals || vals.length === 0) return null
                var idx = Math.min(root.mprisPlayerIndex, vals.length - 1)
                return vals[idx]
            }

            onMprisOpenChanged: {
                if (mprisOpen) mprisVisible = true
                else mprisHideTimer.start()
            }
            // Position tick — manually emit positionChanged() so the binding updates
            Timer {
                id: mprisPosTick
                interval: 1000
                running: root.mprisPlayer !== null && root.mprisPlayer.isPlaying
                repeat: true
                onTriggered: { if (root.mprisPlayer) root.mprisPlayer.positionChanged() }
            }

            // ── Brightness helpers ────────────────────────────────────────────
            Process {
                id: brightnessReadProc
                command: ["sh", "-c",
                    "max=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -1); " +
                    "cur=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -1); " +
                    "[ -n \"$max\" ] && [ \"$max\" -gt 0 ] && echo \"$cur $max\" || echo '128 255'"
                ]
                stdout: SplitParser {
                    onRead: data => {
                        var parts = data.trim().split(" ")
                        if (parts.length >= 2) {
                            var cur = parseInt(parts[0])
                            var max = parseInt(parts[1])
                            if (max > 0) root.brightnessLevel = cur / max
                        }
                    }
                }
            }
            Process {
                id: brightnessWriteProc
                property real targetLevel: 0
                command: ["sh", "-c",
                    "brightnessctl set " + Math.round(brightnessWriteProc.targetLevel * 100) + "% 2>/dev/null || " +
                    "echo " + Math.round(brightnessWriteProc.targetLevel * 255) + " | tee /sys/class/backlight/*/brightness 2>/dev/null || true"
                ]
            }
            Timer {
                interval: 5000; running: true; repeat: true
                Component.onCompleted: { brightnessReadProc.running = true }
                onTriggered: brightnessReadProc.running = true
            }

            // ── Bar layout ────────────────────────────────────────────────────
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: root.gbBg
                border.color: root.gbBg2
                border.width: 1
            }

            // LEFT section - anchored to left
            RowLayout {
                id: leftSection
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                // NixOS logo — click to open power menu
                Item {
                    id: nixosLogoItem
                    implicitWidth: 36
                    implicitHeight: parent.height

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30; height: 30; radius: 8
                        color: root.gbBg1
                        opacity: nixosLogoHover.containsMouse ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf313"
                        color: nixosLogoHover.containsMouse ? root.gbAqua : root.gbBlue
                        font.family: root.f
                        font.pixelSize: 30
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: nixosLogoHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.ccOpen = !root.ccOpen
                    }
                }

                
                RowLayout {
                    spacing: 6
                    Repeater {
                        model: shell.workspaces

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

                            opacity: modelData.output === (shell.workspaces.find(w => w.is_focused)?.output ?? "")
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

            // CENTER — clock with hover highlight (absolutely centered)
            Item {
                id: clockContainer
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth:  clockText.implicitWidth + 16
                implicitHeight: parent.height
                z: 10  // Ensure clock stays on top if there's overlap

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

            // RIGHT section - anchored to right
            RowLayout {
                id: rightSection
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                // MPRIS mini bar — FIRST (leftmost in right section)
                Item {
                    id: mprisBarItem
                    implicitWidth:  mprisBarRow.implicitWidth + 14
                    implicitHeight: parent.height
                    visible: Mpris.players.values.length > 0

                    Rectangle {
                        anchors.centerIn: parent
                        width:  parent.implicitWidth
                        height: 26
                        radius: 6
                        color:  root.gbBg1
                        opacity: mprisBarHover.containsMouse ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    RowLayout {
                        id: mprisBarRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: {
                                var p = root.mprisPlayer
                                if (!p) return "\uf001"
                                return p.isPlaying ? "\uf04c" : ""
                            }
                            color: root.gbPurple
                            font.family: root.f
                            font.pixelSize: 11
                        }

                        Text {
                            text: {
                                var p = root.mprisPlayer
                                if (!p || !p.trackTitle) return ""
                                var t = p.trackTitle
                                return t.length > 20 ? t.substring(0, 20) + "…" : t
                            }
                            color: root.gbFg
                            font.family: root.f
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        id: mprisBarHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.mprisOpen = !root.mprisOpen
                        }

                        onEntered: {
                            mprisKeepOpenTimer.stop()
                        }

                        onExited: {
                            if (root.mprisOpen && !mprisPopup.anyHovered) {
                                mprisKeepOpenTimer.start()
                            }
                        }
                    }
                }

                // Combined CPU/RAM/DSK icon with popup
                Item {
                    implicitWidth:  32
                    implicitHeight: parent.height

                    Rectangle {
                        anchors.centerIn: parent
                        width:   25
                        height:  25
                        radius:  6
                        color:   root.gbBg1
                        opacity: statsIconHover.containsMouse ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    Text {
                        id: statsIconText
                        anchors.centerIn: parent
                        text: "\uf2db"
                        color: root.gbFg
                        font.family: root.f
                        font.pixelSize: 20
                    }

                    MouseArea {
                        id: statsIconHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.statsOpen = !root.statsOpen
                        onExited:root.statsOpen = !root.statsOpen
                    }
                }

                // Brightness icon (popup on hover)
                Item {
                    id: brightnessBarIcon
                    implicitWidth:  32
                    implicitHeight: parent.height

                    Rectangle {
                        anchors.centerIn: parent
                        width: 25; height: 25; radius: 6
                        color: root.gbBg1
                        opacity: brightnessIconHover.containsMouse ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: {
                            var b = root.brightnessLevel
                            if (b < 0.25) return "\uf10c"
                            if (b < 0.60) return "\uf522"
                            return "\uf185"
                        }
                        color: root.gbYellow
                        font.family: root.f
                        font.pixelSize: 20
                    }

                    MouseArea {
                        id: brightnessIconHover
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.brightnessOpen = true
                        onExited:  root.brightnessOpen = false
                        onWheel: wheel => {
                            var delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                            root.brightnessLevel = Math.max(0.01, Math.min(1.0, root.brightnessLevel + delta))
                            brightnessWriteProc.targetLevel = root.brightnessLevel
                            brightnessWriteProc.running = true
                        }
                    }
                }

                // Volume icon (popup on hover)
                Item {
                    id: volumeBarIcon
                    implicitWidth:  32
                    implicitHeight: parent.height

                    Rectangle {
                        anchors.centerIn: parent
                        width:   25
                        height:  25
                        radius:  6
                        color:   root.gbBg1
                        opacity: volumeIconHover.containsMouse ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: {
                            var sink = Pipewire.defaultAudioSink
                            if (!sink || sink.audio.muted) return "\uf6a9"
                            var v = sink.audio.volume
                            if (v < 0.33) return "\ueee8"
                            if (v < 0.66) return "\uf027"
                            return "\uf028"
                        }
                        color: {
                            var sink = Pipewire.defaultAudioSink
                            if (!sink || sink.audio.muted) return root.gbBg4
                            return root.gbAqua
                        }
                        font.family: root.f
                        font.pixelSize: 22
                    }

                    MouseArea {
                        id: volumeIconHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.volumeOpen = true
                        onExited: root.volumeOpen = false
                        onWheel: wheel => {
                            var sink = Pipewire.defaultAudioSink
                            if (!sink) return
                            var delta = wheel.angleDelta.y > 0 ? 0.03 : -0.03
                            sink.audio.volume = Math.max(0, sink.audio.volume + delta)
                        }
                    }
                }


                // Battery
                Rectangle {
                    visible: shell.batteryLevel !== ""
                    height: 22
                    width: batteryText.implicitWidth + 16
                    radius: 6

                    color: shell.batteryStatus === "Charging"      ? Qt.rgba(0.18, 0.47, 0.18, 0.35)
                         : parseInt(shell.batteryLevel) < 20       ? Qt.rgba(0.98, 0.29, 0.20, 0.35)
                         :                                            "transparent"

                    border.width: 1
                    border.color: shell.batteryStatus === "Charging"      ? root.gbGreen
                                : parseInt(shell.batteryLevel) < 20       ? root.gbRed
                                :                                            root.gbBg2

                    Text {
                        id: batteryText
                        anchors.centerIn: parent
                        font.family: root.f
                        font.pixelSize: 14

                        property string icon: {
                            if (shell.batteryStatus === "Charging")        return "\uf1e6 "
                            var n = parseInt(shell.batteryLevel)
                            if (n < 10)  return "\uf244 "
                            if (n < 30)  return "\uf243 "
                            if (n < 60)  return "\uf242 "
                            if (n < 85)  return "\uf241 "
                            return "\uf240 "
                        }

                        text: icon + shell.batteryLevel
                        color: shell.batteryStatus === "Charging" ? root.gbGreen
                             : parseInt(shell.batteryLevel) < 20  ? root.gbRed
                             :                                       root.gbAqua
                    }
                }
            }

            // ── Calendar popup ────────────────────────────────────────────────
            PopupWindow {
                id: calendarPopup
                visible: root.calendarVisible
                implicitWidth:  268
                implicitHeight: 252

                anchor.window:  root
                // Centered below the clock (which is centered on the bar)
                anchor.rect.x:  (root.width - implicitWidth) / 2
                anchor.rect.y:  root.implicitHeight + 8

                color: "transparent"

                Item {
                    id: calInner
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
                            when: root.calendarOpen
                            PropertyChanges { target: calInner; opacity: 1.0; scale: 1.0 }
                        }
                    ]

                    transitions: [
                        Transition {
                            to: "open"
                            ParallelAnimation {
                                NumberAnimation { target: calInner; property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                                NumberAnimation { target: calInner; property: "scale";   from: 0.92; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                            }
                        },
                        Transition {
                            from: "open"
                            ParallelAnimation {
                                NumberAnimation { target: calInner; property: "opacity"; from: 1.0; to: 0.0; duration: 180; easing.type: Easing.InCubic }
                                NumberAnimation { target: calInner; property: "scale";   from: 1.0; to: 0.92; duration: 180; easing.type: Easing.InCubic }
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

            // ── Stats popup ───────────────────────────────────────────────────
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
                                NumberAnimation { target: statsInner; property: "scale";   from: 0.92; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                            }
                        },
                        Transition {
                            from: "open"
                            ParallelAnimation {
                                NumberAnimation { target: statsInner; property: "opacity"; from: 1.0; to: 0.0; duration: 180; easing.type: Easing.InCubic }
                                NumberAnimation { target: statsInner; property: "scale";   from: 1.0; to: 0.92; duration: 180; easing.type: Easing.InCubic }
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
                                    var n = parseInt(shell.cpuUsage)
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
                                    text: shell.cpuUsage
                                    color: {
                                        var n = parseInt(shell.cpuUsage)
                                        return n > 80 ? root.gbRed : n > 50 ? root.gbOrange : root.gbGreen
                                    }
                                    font.family: root.f
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Text {
                                    text: shell.cpuTemp ? shell.cpuTemp + "°" : ""
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
                                    var n = parseInt(shell.ramUsage)
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
                                    text: shell.ramUsage
                                    color: {
                                        var n = parseInt(shell.ramUsage)
                                        return n > 80 ? root.gbRed : root.gbYellow
                                    }
                                    font.family: root.f
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Text {
                                    text: shell.ramUsed ? shell.ramUsed + " / " + shell.ramTotal + " GB" : ""
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
                                    text: shell.diskUsage
                                    color: root.gbPurple
                                    font.family: root.f
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                Text {
                                    text: shell.diskUsed ? shell.diskUsed + " / " + shell.diskTotal + " GB" : ""
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


            // ── Volume + Audio output popup ───────────────────────────────────
            PopupWindow {
                id: volumePopup
                visible: root.volumeVisible
                implicitWidth:  260
                implicitHeight: 100 + (root.audioSinks.length > 0 ? root.audioSinks.length * 46 + 32 : 0)

                anchor.window:  root
                anchor.rect.x:  root.width - implicitWidth - 50
                anchor.rect.y:  root.implicitHeight + 8

                color: "transparent"

                Item {
                    id: volumeInner
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
                            when: root.volumeOpen
                            PropertyChanges { target: volumeInner; opacity: 1.0; scale: 1.0 }
                        }
                    ]

                    transitions: [
                        Transition {
                            to: "open"
                            ParallelAnimation {
                                NumberAnimation { target: volumeInner; property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                                NumberAnimation { target: volumeInner; property: "scale";   from: 0.92; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                            }
                        },
                        Transition {
                            from: "open"
                            ParallelAnimation {
                                NumberAnimation { target: volumeInner; property: "opacity"; from: 1.0; to: 0.0; duration: 180; easing.type: Easing.InCubic }
                                NumberAnimation { target: volumeInner; property: "scale";   from: 1.0; to: 0.92; duration: 180; easing.type: Easing.InCubic }
                            }
                        }
                    ]

                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        // ── Volume row ────────────────────────────────────────
                        RowLayout {
                            width: parent.width

                            // Mute toggle button
                            Text {
                                text: {
                                    var sink = Pipewire.defaultAudioSink
                                    if (!sink || sink.audio.muted) return "\uf6a9"
                                    var v = sink.audio.volume
                                    if (v < 0.33) return "\ueee8"
                                    if (v < 0.66) return "\uf027"
                                    return "\uf028"
                                }
                                color: {
                                    var sink = Pipewire.defaultAudioSink
                                    if (!sink || sink.audio.muted) return root.gbBg4
                                    return root.gbAqua
                                }
                                font.family: root.f
                                font.pixelSize: 14
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var sink = Pipewire.defaultAudioSink
                                        if (sink) sink.audio.muted = !sink.audio.muted
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            Text {
                                text: "VOL"
                                color: root.gbFg4
                                font.family: root.f
                                font.pixelSize: 12
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: {
                                    var sink = Pipewire.defaultAudioSink
                                    if (!sink || sink.audio.muted) return "Muted"
                                    return Math.round((sink.audio.volume ?? 0) * 100) + "%"
                                }
                                color: {
                                    var sink = Pipewire.defaultAudioSink
                                    var v = sink ? Math.round((sink.audio.volume ?? 0) * 100) : 0
                                    if (!sink || sink.audio.muted) return root.gbBg4
                                    return v > 100 ? root.gbOrange : root.gbAqua
                                }
                                font.family: root.f
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        // Volume bar (click/drag to set, scroll also works on icon)
                        Rectangle {
                            id: volBarTrack
                            width: parent.width
                            height: 6
                            radius: 3
                            color:  root.gbBg2

                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                implicitWidth: {
                                    var sink = Pipewire.defaultAudioSink
                                    if (!sink || sink.audio.muted) return 0
                                    return parent.width * Math.min(sink.audio.volume, 1.0)
                                }
                                radius: parent.radius
                                color: {
                                    var sink = Pipewire.defaultAudioSink
                                    var v = sink ? sink.audio.volume : 0
                                    return v > 1.0 ? root.gbOrange : root.gbAqua
                                }
                                Behavior on implicitWidth { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    var sink = Pipewire.defaultAudioSink
                                    if (sink) sink.audio.volume = mouse.x / width
                                }
                                onPositionChanged: mouse => {
                                    if (pressed) {
                                        var sink = Pipewire.defaultAudioSink
                                        if (sink) sink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                                    }
                                }
                            }
                        }

                        // ── Divider + output switcher section ─────────────────
                        Item { width: parent.width; height: 4 }

                        RowLayout {
                            width: parent.width

                            Text {
                                text: "\uf025"
                                color: root.gbAqua
                                font.family: root.f
                                font.pixelSize: 12
                            }
                            Text {
                                text: "Output"
                                color: root.gbFg4
                                font.family: root.f
                                font.pixelSize: 11
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "\uf021"
                                color: volRefreshMa.containsMouse ? root.gbYellow : root.gbBg4
                                font.family: root.f
                                font.pixelSize: 11
                                Behavior on color { ColorAnimation { duration: 100 } }
                                MouseArea {
                                    id: volRefreshMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: audioSinkPollProc.running = true
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.gbBg2
                        }

                        // Sink list
                        Repeater {
                            model: root.audioSinks

                            delegate: Item {
                                required property string modelData
                                required property int    index

                                width:  parent.width
                                height: 40

                                property bool isDefault: modelData === root.defaultSinkName
                                property bool hovered:   sinkMa.containsMouse

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: isDefault ? Qt.rgba(0.55, 0.76, 0.49, 0.15)
                                         : hovered   ? root.gbBg2
                                         :             "transparent"
                                    border.color: isDefault ? root.gbGreen : "transparent"
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    spacing: 8

                                    Text {
                                        text: {
                                            var n = modelData.toLowerCase()
                                            if (n.indexOf("headphone") !== -1 || n.indexOf("headset") !== -1) return "\uf025"
                                            if (n.indexOf("hdmi") !== -1) return "\uf26c"
                                            if (n.indexOf("bluetooth") !== -1 || n.indexOf("bluez") !== -1) return "\uf293"
                                            if (n.indexOf("usb") !== -1) return "\uf287"
                                            return "\uf028"
                                        }
                                        color: isDefault ? root.gbGreen : root.gbFg4
                                        font.family: root.f
                                        font.pixelSize: 14
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: {
                                            var n = modelData
                                            n = n.replace(/^alsa_output\./, "")
                                            n = n.replace(/^bluez_sink\./, "BT: ")
                                            n = n.replace(/[_\.]/g, " ").trim()
                                            if (n.length > 0) n = n.charAt(0).toUpperCase() + n.slice(1)
                                            return n.length > 26 ? n.substring(0, 26) + "…" : n
                                        }
                                        color: isDefault ? root.gbFg : root.gbFg4
                                        font.family: root.f
                                        font.pixelSize: 11
                                        font.bold: isDefault
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }

                                    Text {
                                        visible: isDefault
                                        text: "\uf00c"
                                        color: root.gbGreen
                                        font.family: root.f
                                        font.pixelSize: 11
                                    }
                                }

                                MouseArea {
                                    id: sinkMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!isDefault) {
                                            audioSinkSetProc.targetSink = modelData
                                            audioSinkSetProc.running = true
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.audioSinks.length === 0
                            text: "Scanning…"
                            color: root.gbBg4
                            font.family: root.f
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        propagateComposedEvents: true
                        onPressed: mouse => mouse.accepted = false
                    }
                }
            }

            // ── Brightness popup ─────────────────────────────────────────────
            PopupWindow {
                id: brightnessPopup
                visible: root.brightnessVisible
                implicitWidth:  200
                implicitHeight: 72
                anchor.window:  root
                anchor.rect.x:  root.width - implicitWidth - 90
                anchor.rect.y:  root.implicitHeight + 8
                color: "transparent"

                Item {
                    id: brightnessInner
                    anchors.fill: parent; opacity: 0; scale: 0.92
                    transformOrigin: Item.Top

                    Rectangle { anchors.fill: parent; radius: 12; color: root.gbBg1; border.color: root.gbBg2; border.width: 1 }

                    states: [ State { name: "open"; when: root.brightnessOpen
                        PropertyChanges { target: brightnessInner; opacity: 1.0; scale: 1.0 } } ]
                    transitions: [
                        Transition { to: "open"; ParallelAnimation {
                            NumberAnimation { target: brightnessInner; property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                            NumberAnimation { target: brightnessInner; property: "scale";   from: 0.92; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                        }},
                        Transition { from: "open"; ParallelAnimation {
                            NumberAnimation { target: brightnessInner; property: "opacity"; from: 1.0; to: 0.0; duration: 180; easing.type: Easing.InCubic }
                            NumberAnimation { target: brightnessInner; property: "scale";   from: 1.0; to: 0.92; duration: 180; easing.type: Easing.InCubic }
                        }}
                    ]

                    Column {
                        anchors.fill: parent; anchors.margins: 14; spacing: 10

                        RowLayout {
                            width: parent.width
                            Text {
                                text: { var b = root.brightnessLevel; if (b < 0.25) return "\uf10c"; if (b < 0.60) return "\uf522"; return "\uf185" }
                                color: root.gbYellow; font.family: root.f; font.pixelSize: 14
                            }
                            Text { text: "BRI"; color: root.gbFg4; font.family: root.f; font.pixelSize: 12 }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Math.round(root.brightnessLevel * 100) + "%"
                                color: root.gbYellow; font.family: root.f; font.pixelSize: 12; font.bold: true
                            }
                        }

                        Rectangle {
                            width: parent.width; height: 6; radius: 3; color: root.gbBg2
                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                implicitWidth: parent.width * root.brightnessLevel
                                radius: parent.radius; color: root.gbYellow
                                Behavior on implicitWidth { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                    MouseArea { anchors.fill: parent; propagateComposedEvents: true; onPressed: mouse => mouse.accepted = false }
                }
            }

        // ── Control Center popup ──────────────────────────────────────────
        PopupWindow {
            id: ccPopup
            visible: root.ccVisible
            implicitWidth:  320
            implicitHeight: 520

            anchor.window: root
            anchor.rect.x: 14
            anchor.rect.y: root.implicitHeight + 8

            color: "transparent"

            Item {
                id: ccInner
                anchors.fill: parent
                opacity: 0
                scale: 0.94
                transformOrigin: Item.TopLeft

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: root.gbBg
                    border.color: root.gbBg2
                    border.width: 1
                }

                states: State {
                    name: "open"
                    when: root.ccOpen
                    PropertyChanges { target: ccInner; opacity: 1.0; scale: 1.0 }
                }
                transitions: [
                    Transition { to: "open"; ParallelAnimation {
                        NumberAnimation { target: ccInner; property: "opacity"; from: 0.0; to: 1.0; duration: 220; easing.type: Easing.OutCubic }
                        NumberAnimation { target: ccInner; property: "scale";   from: 0.94; to: 1.0; duration: 220; easing.type: Easing.OutCubic }
                    }},
                    Transition { from: "open"; ParallelAnimation {
                        NumberAnimation { target: ccInner; property: "opacity"; from: 1.0; to: 0.0; duration: 180; easing.type: Easing.InCubic }
                        NumberAnimation { target: ccInner; property: "scale";   from: 1.0; to: 0.94; duration: 180; easing.type: Easing.InCubic }
                    }}
                ]

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 14
                    contentHeight: ccColumn.implicitHeight
                    clip: true
                    flickableDirection: Flickable.VerticalFlick


                    Column {
                        id: ccColumn
                        width: parent.width
                        spacing: 14

                        // ── Header ────────────────────────────────────────────
                        RowLayout {
                            width: parent.width
                            Text {
                                text: "\uf313"
                                color: root.gbBlue
                                font.family: root.f
                                font.pixelSize: 18
                            }
                            Text {
                                text: "Control Center"
                                color: root.gbFg
                                font.family: root.f
                                font.pixelSize: 14
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "\uf00d"
                                color: closeMa.containsMouse ? root.gbRed : root.gbBg4
                                font.family: root.f
                                font.pixelSize: 13
                                Behavior on color { ColorAnimation { duration: 100 } }
                                MouseArea {
                                    id: closeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.ccOpen = false
                                }
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: root.gbBg2 }

                        // ── Network ───────────────────────────────────────────
                        Rectangle {
                            width: parent.width; height: 52; radius: 10
                            color: root.gbBg1
                            border.color: root.gbBg2; border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Text {
                                    text: root.ccNetworkName === "Not connected" ? "\uf127" : "\uf1eb"
                                    color: root.ccNetworkName === "Not connected" ? root.gbBg4 : root.gbGreen
                                    font.family: root.f; font.pixelSize: 18
                                }
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "Network"; color: root.gbFg4; font.family: root.f; font.pixelSize: 10 }
                                    Text {
                                        text: root.ccNetworkName + (root.ccNetworkSignal !== "" ? "  " + root.ccNetworkSignal : "")
                                        color: root.gbFg; font.family: root.f; font.pixelSize: 12; font.bold: true
                                    }
                                }
                                Text {
                                    text: "\uf021"
                                    color: netRefMa.containsMouse ? root.gbYellow : root.gbBg4
                                    font.family: root.f; font.pixelSize: 12
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    MouseArea {
                                        id: netRefMa
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: ccNetworkProc.running = true
                                    }
                                }
                            }
                        }

                        // ── Bluetooth ─────────────────────────────────────────
                        Rectangle {
                            width: parent.width
                            height: root.ccBluetoothDevices.length > 0 ? 52 + root.ccBluetoothDevices.length * 24 : 52
                            radius: 10
                            color: root.gbBg1
                            border.color: root.gbBg2; border.width: 1

                            Column {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6

                                RowLayout {
                                    width: parent.width
                                    spacing: 10
                                    Text {
                                        text: "\uf294"
                                        color: root.ccBluetoothStatus === "on" ? root.gbBlue : root.gbBg4
                                        font.family: root.f; font.pixelSize: 18
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                    Column {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text { text: "Bluetooth"; color: root.gbFg4; font.family: root.f; font.pixelSize: 10 }
                                        Text {
                                            text: root.ccBluetoothStatus === "on"
                                                ? (root.ccBluetoothDevices.length > 0 ? root.ccBluetoothDevices.length + " device(s)" : "On, no devices")
                                                : "Off"
                                            color: root.gbFg; font.family: root.f; font.pixelSize: 12; font.bold: true
                                        }
                                    }
                                    Rectangle {
                                        width: 36; height: 20; radius: 10
                                        color: root.ccBluetoothStatus === "on" ? root.gbBlue : root.gbBg2
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Rectangle {
                                            width: 14; height: 14; radius: 7
                                            color: "white"
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: root.ccBluetoothStatus === "on" ? parent.width - 17 : 3
                                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.ccBluetoothStatus === "on") {
                                                    Quickshell.execDetached(["sh", "-c", "bluetoothctl power off"])
                                                    root.ccBluetoothStatus = "off"
                                                } else {
                                                    Quickshell.execDetached(["sh", "-c", "bluetoothctl power on"])
                                                    root.ccBluetoothStatus = "on"
                                                }
                                            }
                                        }
                                    }
                                }

                                Repeater {
                                    model: root.ccBluetoothDevices
                                    Text {
                                        required property string modelData
                                        text: "\uf10c  " + modelData
                                        color: root.gbFg4
                                        font.family: root.f; font.pixelSize: 10
                                        width: parent.width
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        // ── Quick toggles ─────────────────────────────────────
                        // Uses Row with explicit widths — NOT RowLayout/Layout.fillWidth
                        // (Layout.fillWidth inside a Column doesn't size correctly)
                        Rectangle {
                            width: parent.width; height: 80; radius: 10
                            color: root.gbBg1
                            border.color: root.gbBg2; border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                // Night light
                                Column {
                                    width: (parent.width - 16) / 3
                                    spacing: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        width: parent.width; height: 36; radius: 8
                                        color: root.ccNightLight
                                            ? Qt.rgba(0.99, 0.74, 0.19, 0.25)
                                            : nlMa.containsMouse ? root.gbBg2 : "transparent"
                                        border.color: root.ccNightLight ? root.gbYellow : root.gbBg2
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf186"
                                            color: root.ccNightLight ? root.gbYellow : root.gbFg4
                                            font.family: root.f; font.pixelSize: 16
                                        }
                                        MouseArea {
                                            id: nlMa
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.ccNightLight = !root.ccNightLight
                                                if (root.ccNightLight)
                                                    Quickshell.execDetached(["sh", "-c", "wlsunset -l 28.6 -L 77.2"])
                                                else
                                                    Quickshell.execDetached(["sh", "-c", "pkill wlsunset || true"])
                                            }
                                        }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Night"
                                        color: root.ccNightLight ? root.gbYellow : root.gbFg4
                                        font.family: root.f; font.pixelSize: 9
                                    }
                                }

                                // Do not disturb
                                Column {
                                    width: (parent.width - 16) / 3
                                    spacing: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        width: parent.width; height: 36; radius: 8
                                        color: root.ccDoNotDisturb
                                            ? Qt.rgba(0.98, 0.29, 0.20, 0.20)
                                            : dndMa.containsMouse ? root.gbBg2 : "transparent"
                                        border.color: root.ccDoNotDisturb ? root.gbRed : root.gbBg2
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf1f6"
                                            color: root.ccDoNotDisturb ? root.gbRed : root.gbFg4
                                            font.family: root.f; font.pixelSize: 16
                                        }
                                        MouseArea {
                                            id: dndMa
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.ccDoNotDisturb = !root.ccDoNotDisturb
                                        }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "DnD"
                                        color: root.ccDoNotDisturb ? root.gbRed : root.gbFg4
                                        font.family: root.f; font.pixelSize: 9
                                    }
                                }

                                // Refresh
                                Column {
                                    width: (parent.width - 16) / 3
                                    spacing: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        width: parent.width; height: 36; radius: 8
                                        color: rfMa.containsMouse ? root.gbBg2 : "transparent"
                                        border.color: root.gbBg2; border.width: 1
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "\uf021"
                                            color: rfMa.containsMouse ? root.gbGreen : root.gbFg4
                                            font.family: root.f; font.pixelSize: 16
                                        }
                                        MouseArea {
                                            id: rfMa
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                ccNetworkProc.running   = true
                                                ccBluetoothProc.running = true
                                            }
                                        }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Refresh"
                                        color: root.gbFg4; font.family: root.f; font.pixelSize: 9
                                    }
                                }
                            }
                        }

                        // ── Wallpapers ────────────────────────────────────────
                        Column {
                            width: parent.width
                            spacing: 8

                            RowLayout {
                                width: parent.width
                                Text {
                                    text: "\uf03e  Wallpapers"
                                    color: root.gbFg4; font.family: root.f; font.pixelSize: 11
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "\uf021"
                                    color: wallRefMa.containsMouse ? root.gbYellow : root.gbBg4
                                    font.family: root.f; font.pixelSize: 11
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    MouseArea {
                                        id: wallRefMa
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: ccWallpaperProc.running = true
                                    }
                                }
                            }

                            // Grid — no Flickable needed here because the outer
                            // Flickable already scrolls the whole panel
                            Grid {
                                id: wallGrid
                                width: parent.width
                                columns: 2
                                spacing: 6

                                Repeater {
                                    model: root.ccWallpapers

                                    delegate: Item {
                                        required property string modelData
                                        required property int index
                                        width:  (wallGrid.width - 6) / 2
                                        height: 70

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            color: root.gbBg1
                                            border.color: root.ccActiveWall === modelData
                                                ? root.gbYellow
                                                : wallMa.containsMouse ? root.gbBg4 : root.gbBg2
                                            border.width: root.ccActiveWall === modelData ? 2 : 1
                                            Behavior on border.color { ColorAnimation { duration: 100 } }
                                            clip: true

                                            Image {
                                                anchors.fill: parent
                                                anchors.margins: 2
                                                source: "file://" + modelData
                                                fillMode: Image.PreserveAspectCrop
                                                smooth: true
                                                asynchronous: true
                                            }

                                            Rectangle {
                                                visible: root.ccActiveWall === modelData
                                                anchors { top: parent.top; right: parent.right; margins: 5 }
                                                width: 14; height: 14; radius: 7
                                                color: root.gbYellow
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "\uf00c"
                                                    color: root.gbBg
                                                    font.family: root.f; font.pixelSize: 8
                                                }
                                            }

                                            MouseArea {
                                                id: wallMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    var path = modelData
                                                    root.ccActiveWall = path
                                                    Quickshell.execDetached(["sh", "-c", "pkill swaybg; sleep 0.1; swaybg -m fill -i '" + path + "'"])
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: root.ccWallpapers.length === 0
                                    text: "No wallpapers found in ~/wallpapers"
                                    color: root.gbBg4
                                    font.family: root.f; font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                    width: wallGrid.width
                                }
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: root.gbBg2 }

                        // ── Power row ─────────────────────────────────────────
                        RowLayout {
                            width: parent.width
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 8
                                color: ccPwrMa.containsMouse ? Qt.rgba(0.98, 0.29, 0.20, 0.22) : "transparent"
                                border.color: ccPwrMa.containsMouse ? root.gbRed : root.gbBg2; border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Row { anchors.centerIn: parent; spacing: 6
                                    Text { text: "\uf011"; color: root.gbRed; font.family: root.f; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Off";    color: root.gbFg;  font.family: root.f; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea { id: ccPwrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.createQmlObject('import Quickshell.Io; Process { command: ["systemctl","poweroff"]; running: true }', ccPopup, "p") }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 8
                                color: ccRstMa.containsMouse ? Qt.rgba(0.99, 0.74, 0.19, 0.18) : "transparent"
                                border.color: ccRstMa.containsMouse ? root.gbYellow : root.gbBg2; border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Row { anchors.centerIn: parent; spacing: 6
                                    Text { text: "\uf021"; color: root.gbYellow; font.family: root.f; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Restart"; color: root.gbFg;    font.family: root.f; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea { id: ccRstMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.createQmlObject('import Quickshell.Io; Process { command: ["systemctl","reboot"]; running: true }', ccPopup, "r") }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 36; radius: 8
                                color: ccSusMa.containsMouse ? Qt.rgba(0.52, 0.63, 0.60, 0.18) : "transparent"
                                border.color: ccSusMa.containsMouse ? root.gbAqua : root.gbBg2; border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Row { anchors.centerIn: parent; spacing: 6
                                    Text { text: "\uf186"; color: root.gbAqua; font.family: root.f; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Sleep";  color: root.gbFg;   font.family: root.f; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea { id: ccSusMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.createQmlObject('import Quickshell.Io; Process { command: ["systemctl","suspend"]; running: true }', ccPopup, "s") }
                            }
                        }

                        // bottom padding so last item isn't flush against edge
                        Item { width: 1; height: 4 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    propagateComposedEvents: true
                    onPressed: mouse => mouse.accepted = false
                }
            }
        }

            
// ── Power popup ───────────────────────────────────────────────────
PopupWindow {
    id: powerPopup
    visible: root.powerVisible
    implicitWidth:  180
    implicitHeight: 160

    anchor.window: root
    anchor.rect.x: 14
    anchor.rect.y: root.implicitHeight + 8

    color: "transparent"

    Item {
        id: powerInner
        anchors.fill: parent
        opacity: 0
        scale: 0.92
        transformOrigin: Item.TopLeft

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: root.gbBg1
            border.color: root.gbBg2
            border.width: 1
        }

        states: State {
            name: "open"
            when: root.powerOpen
            PropertyChanges { target: powerInner; opacity: 1.0; scale: 1.0 }
        }

        transitions: [
            Transition {
                to: "open"
                ParallelAnimation {
                    NumberAnimation { target: powerInner; property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { target: powerInner; property: "scale";   from: 0.92; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                }
            },
            Transition {
                from: "open"
                ParallelAnimation {
                    NumberAnimation { target: powerInner; property: "opacity"; from: 1.0; to: 0.0; duration: 180; easing.type: Easing.InCubic }
                    NumberAnimation { target: powerInner; property: "scale";   from: 1.0; to: 0.92; duration: 180; easing.type: Easing.InCubic }
                }
            }
        ]

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            // Power off
            Rectangle {
                width: parent.width; height: 40; radius: 8
                color: powerOffMa.containsMouse ? Qt.rgba(0.98, 0.29, 0.20, 0.25) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                border.color: powerOffMa.containsMouse ? root.gbRed : root.gbBg2
                border.width: 1
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "\uf011"; color: root.gbRed; font.family: root.f; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Power Off";  color: root.gbFg; font.family: root.f; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: powerOffMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.createQmlObject(
                        'import Quickshell.Io; Process { command: ["systemctl","poweroff"]; running: true }',
                        powerPopup, "powerOff"
                    )
                }
            }

            // Restart
            Rectangle {
                width: parent.width; height: 40; radius: 8
                color: restartMa.containsMouse ? Qt.rgba(0.98, 0.69, 0.18, 0.20) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                border.color: restartMa.containsMouse ? root.gbYellow : root.gbBg2
                border.width: 1
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "\uf021"; color: root.gbYellow; font.family: root.f; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Restart";    color: root.gbFg;   font.family: root.f; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: restartMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.createQmlObject(
                        'import Quickshell.Io; Process { command: ["systemctl","reboot"]; running: true }',
                        powerPopup, "reboot"
                    )
                }
            }

            // Suspend
            Rectangle {
                width: parent.width; height: 40; radius: 8
                color: suspendMa.containsMouse ? Qt.rgba(0.52, 0.63, 0.60, 0.20) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }
                border.color: suspendMa.containsMouse ? root.gbAqua : root.gbBg2
                border.width: 1
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "\uf186"; color: root.gbAqua; font.family: root.f; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Suspend";    color: root.gbFg; font.family: root.f; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: suspendMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.createQmlObject(
                        'import Quickshell.Io; Process { command: ["systemctl","suspend"]; running: true }',
                        powerPopup, "suspend"
                    )
                }
            }
        }
    }
}
            // ── MPRIS popup ───────────────────────────────────────────────────
PopupWindow {
    id: mprisPopup
    visible: root.mprisVisible
    implicitWidth:  310
    implicitHeight: Mpris.players.values.length > 1 ? 230 : 230
    anchor.window: root

    property bool containsMouse: false
    
    // Individual hover states
    property bool backgroundHovered: false
    property bool shuffleHovered: false
    property bool prevHovered: false
    property bool playHovered: false
    property bool nextHovered: false
    property bool loopHovered: false
    property bool playerSwitcherHovered: false

    // True if ANY part is hovered
    readonly property bool anyHovered: backgroundHovered || shuffleHovered || prevHovered || 
                                        playHovered || nextHovered || loopHovered || playerSwitcherHovered

    // Watch for changes and manage timer
    onAnyHoveredChanged: {
        if (anyHovered) {
            mprisKeepOpenTimer.stop()
            containsMouse = true
        } else {
            // Nothing hovered in popup - start timer to close
            mprisKeepOpenTimer.start()
        }
    }

    // Also watch visible to reset state
    onVisibleChanged: {
        if (!visible) {
            // Reset all hover states when closed
            backgroundHovered = false
            shuffleHovered = false
            prevHovered = false
            playHovered = false
            nextHovered = false
            loopHovered = false
            playerSwitcherHovered = false
            containsMouse = false
        }
    }

    anchor.rect.x: root.width - implicitWidth - 50
    anchor.rect.y: root.implicitHeight + 8
    color: "transparent"

    Item {
        id: mprisInner
        anchors.fill: parent
        opacity: 0
        scale: 0.92
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
                when: root.mprisOpen
                PropertyChanges { target: mprisInner; opacity: 1.0; scale: 1.0 }
            }
        ]

        transitions: [
            Transition {
                to: "open"
                ParallelAnimation {
                    NumberAnimation { target: mprisInner; property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { target: mprisInner; property: "scale"; from: 0.92; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                }
            },
            Transition {
                from: "open"
                ParallelAnimation {
                    NumberAnimation { target: mprisInner; property: "opacity"; from: 1.0; to: 0.0; duration: 180; easing.type: Easing.InCubic }
                    NumberAnimation { target: mprisInner; property: "scale"; from: 1.0; to: 0.92; duration: 180; easing.type: Easing.InCubic }
                }
            }
        ]

        // Background hover detection
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            
            onEntered: mprisPopup.backgroundHovered = true
            onExited: mprisPopup.backgroundHovered = false
        }

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // ── Album art + track info ────────────────────────────
            RowLayout {
                width: parent.width
                spacing: 12

                Rectangle {
                    width: 58
                    height: 58
                    radius: 8
                    color: root.gbBg2
                    clip: true

                    Image {
                        id: mprisArtImg
                        anchors.fill: parent
                        source: root.mprisPlayer ? (root.mprisPlayer.trackArtUrl || "") : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "\uf001"
                        color: root.gbBg4
                        font.family: root.f
                        font.pixelSize: 26
                        visible: mprisArtImg.status !== Image.Ready
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        width: parent.width
                        text: root.mprisPlayer ? (root.mprisPlayer.trackTitle || "Nothing playing") : "Nothing playing"
                        color: root.gbFg
                        font.family: root.f
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.mprisPlayer ? (root.mprisPlayer.trackArtist || "") : ""
                        color: root.gbFg4
                        font.family: root.f
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.mprisPlayer ? (root.mprisPlayer.trackAlbum || "") : ""
                        color: root.gbBg4
                        font.family: root.f
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                    Text {
                        text: root.mprisPlayer ? (root.mprisPlayer.identity || "") : ""
                        color: root.gbPurple
                        font.family: root.f
                        font.pixelSize: 9
                    }
                }
            }

            // ── Progress bar + timestamps ─────────────────────────
            Column {
                width: parent.width
                spacing: 4

                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: root.gbBg2

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            var p = root.mprisPlayer
                            if (!p || !p.positionSupported || !p.lengthSupported || p.length <= 0) return
                            if (p.canSeek) p.position = (mouse.x / width) * p.length
                        }
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        radius: parent.radius
                        color: root.gbPurple
                        implicitWidth: {
                            var p = root.mprisPlayer
                            if (!p || !p.lengthSupported || p.length <= 0) return 0
                            return parent.width * Math.min(p.position / p.length, 1.0)
                        }
                        Behavior on implicitWidth { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
                    }
                }

                RowLayout {
                    width: parent.width
                    Text {
                        text: {
                            var p = root.mprisPlayer
                            if (!p || !p.positionSupported) return "0:00"
                            var s = Math.floor(p.position)
                            return Math.floor(s/60) + ":" + ("0"+(s%60)).slice(-2)
                        }
                        color: root.gbFg4
                        font.family: root.f
                        font.pixelSize: 9
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: {
                            var p = root.mprisPlayer
                            if (!p || !p.lengthSupported || p.length <= 0) return ""
                            var s = Math.floor(p.length)
                            return Math.floor(s/60) + ":" + ("0"+(s%60)).slice(-2)
                        }
                        color: root.gbFg4
                        font.family: root.f
                        font.pixelSize: 9
                    }
                }
            }

            // ── Controls ──────────────────────────────────────────
            RowLayout {
                width: parent.width

                // Shuffle
                Item {
                    implicitWidth: 28
                    implicitHeight: 28
                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: shuffleMa.containsMouse ? root.gbBg2 : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "\uf074"
                        color: (root.mprisPlayer && root.mprisPlayer.shuffleSupported && root.mprisPlayer.shuffle) ? root.gbGreen : root.gbBg4
                        font.family: root.f
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: shuffleMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: mprisPopup.shuffleHovered = true
                        onExited: mprisPopup.shuffleHovered = false
                        onClicked: {
                            var p = root.mprisPlayer
                            if (p && p.canControl && p.shuffleSupported) p.shuffle = !p.shuffle
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Previous
                Item {
                    implicitWidth: 32
                    implicitHeight: 32
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: prevMa.containsMouse ? root.gbBg2 : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "\uf04a"
                        color: (root.mprisPlayer && root.mprisPlayer.canGoPrevious) ? root.gbFg : root.gbBg4
                        font.family: root.f
                        font.pixelSize: 16
                    }
                    MouseArea {
                        id: prevMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: mprisPopup.prevHovered = true
                        onExited: mprisPopup.prevHovered = false
                        onClicked: {
                            var p = root.mprisPlayer
                            if (p && p.canGoPrevious) p.previous()
                        }
                    }
                }

                // Play / Pause
                Item {
                    implicitWidth: 40
                    implicitHeight: 40
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: playMa.containsMouse ? root.gbPurple : root.gbBg2
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: (root.mprisPlayer && root.mprisPlayer.isPlaying) ? "\uf04c" : "\uf04b"
                        color: root.gbFg
                        font.family: root.f
                        font.pixelSize: 18
                    }
                    MouseArea {
                        id: playMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: mprisPopup.playHovered = true
                        onExited: mprisPopup.playHovered = false
                        onClicked: {
                            var p = root.mprisPlayer
                            if (p && p.canTogglePlaying) p.togglePlaying()
                        }
                    }
                }

                // Next
                Item {
                    implicitWidth: 32
                    implicitHeight: 32
                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: nextMa.containsMouse ? root.gbBg2 : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "\uf04e"
                        color: (root.mprisPlayer && root.mprisPlayer.canGoNext) ? root.gbFg : root.gbBg4
                        font.family: root.f
                        font.pixelSize: 16
                    }
                    MouseArea {
                        id: nextMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: mprisPopup.nextHovered = true
                        onExited: mprisPopup.nextHovered = false
                        onClicked: {
                            var p = root.mprisPlayer
                            if (p && p.canGoNext) p.next()
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Loop
                Item {
                    implicitWidth: 28
                    implicitHeight: 28
                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: loopMa.containsMouse ? root.gbBg2 : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "\uf021"
                        color: {
                            var p = root.mprisPlayer
                            if (!p || !p.loopSupported) return root.gbBg4
                            return p.loopState !== MprisLoopState.None ? root.gbGreen : root.gbBg4
                        }
                        font.family: root.f
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: loopMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: mprisPopup.loopHovered = true
                        onExited: mprisPopup.loopHovered = false
                        onClicked: {
                            var p = root.mprisPlayer
                            if (!p || !p.canControl || !p.loopSupported) return
                            if (p.loopState === MprisLoopState.None) p.loopState = MprisLoopState.Playlist
                            else if (p.loopState === MprisLoopState.Playlist) p.loopState = MprisLoopState.Track
                            else p.loopState = MprisLoopState.None
                        }
                    }
                }
            }

            // ── Player switcher (only when > 1 players) ───────────
            RowLayout {
                width: parent.width
                visible: Mpris.players.values.length > 1

                Text {
                    text: "\uf144"
                    color: root.gbBg4
                    font.family: root.f
                    font.pixelSize: 10
                }

                Repeater {
                    model: Mpris.players.values
                    delegate: Item {
                        required property var modelData
                        required property int index
                        implicitWidth: pDot.width + pName.implicitWidth + 8
                        implicitHeight: 18

                        Rectangle {
                            id: pDot
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            radius: 3
                            color: index === root.mprisPlayerIndex ? root.gbPurple : root.gbBg4
                        }
                        Text {
                            id: pName
                            anchors {
                                verticalCenter: parent.verticalCenter
                                left: pDot.right
                                leftMargin: 4
                            }
                            text: modelData.identity || ""
                            color: index === root.mprisPlayerIndex ? root.gbFg : root.gbFg4
                            font.family: root.f
                            font.pixelSize: 9
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onEntered: mprisPopup.playerSwitcherHovered = true
                            onExited: mprisPopup.playerSwitcherHovered = false
                            onClicked: root.mprisPlayerIndex = index
                        }
                    }
                }
            }
        }
    }
}

       }
    }
}
