import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Scope {
    id: dockRoot

    PersistentProperties {
        id: persist
        reloadableId: "dock-pins"
        property var pinnedApps: []
    }

    QtObject {
        id: tooltipState
        property string text:    ""
        property bool   visible: false
        property real   x:       0
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockWin
            required property var modelData
            screen: modelData

            anchors.bottom: true
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            color: "transparent"

            implicitWidth:  screen.width
            implicitHeight: 120

            
            mask: Region {
                Region { item: dockBg }
                Region { item: triggerStrip }
            }

            property bool dockVisible: false

            // ── Tooltip ──────────────────────────────────────────────────
            Rectangle {
                id: tooltipBox
                visible: tooltipState.visible && dockWin.dockVisible
                x: Math.max(4, Math.min(tooltipState.x - width / 2,
                            dockWin.width - width - 4))
                y: dockBg.y - height - 8
                width:  ttText.implicitWidth + 18
                height: ttText.implicitHeight + 10
                radius: 7
                color:        "#f0282828"
                border.color: "#d79921"
                border.width: 1

                Text {
                    id: ttText
                    anchors.centerIn: parent
                    text: tooltipState.text
                    color: "#ebdbb2"
                    font.pixelSize: 12
                    font.family: "sans-serif"
                }
            }

            // ── Dock pill ────────────────────────────────────────────────
            Rectangle {
                id: dockBg
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: dockWin.dockVisible ? 6 : -80

                width:  dockRow.implicitWidth + 28
                height: 68
                radius: 16
                color:        "#ee282828"
                border.color: "#504945"
                border.width: 1

                opacity: dockWin.dockVisible ? 1.0 : 0.0

                Behavior on anchors.bottomMargin {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 180 }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            hideTimer.stop()
                            dockWin.dockVisible = true
                        } else {
                            hideTimer.restart()
                        }
                    }
                }

                RowLayout {
                    id: dockRow
                    anchors.centerIn: parent
                    spacing: 4

                    // ── Running apps (not pinned) ────────────────────────
                    Repeater {
                        model: ToplevelManager.toplevels

                        delegate: Item {
                            required property var modelData
                            property var t: modelData

                            visible: t && t.appId !== "" &&
                                     persist.pinnedApps.indexOf(t.appId) === -1
                            width:  visible ? 56 : 0
                            height: 56
                            Layout.alignment: Qt.AlignVCenter

                            DockButton {
                                anchors.fill: parent
                                appId:      t ? t.appId : ""
                                toplevel:   t
                                isPinned:   false
                                isRunning:  true
                                dockWinRef: dockWin
                            }
                        }
                    }

                    // ── Divider ──────────────────────────────────────────
                    Rectangle {
                        visible: persist.pinnedApps.length > 0
                        width: 1; height: 36
                        color: "#504945"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // ── Pinned apps ──────────────────────────────────────
                    Repeater {
                        model: persist.pinnedApps

                        delegate: DockButton {
                            required property string modelData
                            property string pinnedAppId: modelData

                            property var liveToplevel: {
                                let tv = ToplevelManager.toplevels.values
                                for (let i = 0; i < tv.length; i++) {
                                    if (tv[i]?.appId === pinnedAppId) return tv[i]
                                }
                                return null
                            }

                            appId:      pinnedAppId
                            isPinned:   true
                            isRunning:  liveToplevel !== null
                            toplevel:   liveToplevel
                            dockWinRef: dockWin
                        }
                    }
                }
            }

            // ── Trigger strip ────────────────────────────────────────────
            Item {
                id:triggerStrip
                anchors.bottom: parent.bottom
                width: parent.width
                height: 6

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            hideTimer.stop()
                            dockWin.dockVisible = true
                        }
                    }
                }
            }

            Timer {
                id: hideTimer
                interval: 700
                repeat: false
                onTriggered: {
                    tooltipState.visible = false
                    dockWin.dockVisible  = false
                }
            }
        }
    }
}
