/*
 * red-night row for the Brightness and Color popup, laid out like NightLightItem.qml:
 * icon, title, status and level on top, a Switch (the pill) underneath.
 * The switch runs the red-night command; the state is read back with `red-night state`.
 */

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmaComponents3.ItemDelegate {
    id: root

    // Absolute path of the red-night command, filled in by red-night-tray.
    required property string command

    property bool known: false  // false until the first `red-night state` answer
    property bool on: false
    property int level: 0
    property bool busy: false

    readonly property bool popupVisible: visible && (Window.window?.visible ?? false)

    background.visible: highlighted
    highlighted: activeFocus
    hoverEnabled: false

    Accessible.description: status.text
    Accessible.onPressAction: flip()
    Keys.onSpacePressed: flip()

    function run(args) {
        executable.connectSource(`'${command}' ${args}`);
    }
    function flip() {
        if (known && !busy) {
            busy = true;
            on = !on;
            run(on ? "on" : "off");
        }
    }
    function refresh() {
        if (!busy) {
            run("state");
        }
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source);
            if (source.endsWith(" state")) {
                const m = /^(on|off) (\d+)/.exec(data.stdout ?? "");
                if (m) {
                    root.on = m[1] === "on";
                    root.level = Number(m[2]);
                    root.known = true;
                }
            } else {
                root.busy = false;
                root.refresh();
            }
        }
    }

    onPopupVisibleChanged: if (popupVisible) refresh()
    Timer {
        // The schedule (or a terminal) can change the state while the popup is open.
        interval: 3000
        repeat: true
        running: root.popupVisible
        onTriggered: root.refresh()
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.gridUnit

        Kirigami.Icon {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            source: root.on ? "redshift-status-on" : "redshift-status-off"
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: "Red Night"
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents3.Label {
                    id: status
                    text: !root.known ? "" : root.on ? i18nd("plasma_applet_org.kde.plasma.brightness", "On")
                                                     : i18nd("plasma_applet_org.kde.plasma.brightness", "Off")
                    textFormat: Text.PlainText
                    opacity: 0.75
                }

                PlasmaComponents3.Label {
                    visible: root.on
                    text: `${root.level}%`
                    font.features: { "tnum": 1 }
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignRight
                }
            }

            PlasmaComponents3.Switch {
                id: redSwitch
                Layout.fillWidth: true
                text: "Red only"
                checked: root.on
                enabled: root.known && !root.busy

                activeFocusOnTab: false
                focusPolicy: Qt.NoFocus
                Accessible.onPressAction: root.flip()

                onToggled: {
                    root.flip();
                    checked = Qt.binding(() => root.on);  // the click broke the binding
                }
            }
        }
    }
}
