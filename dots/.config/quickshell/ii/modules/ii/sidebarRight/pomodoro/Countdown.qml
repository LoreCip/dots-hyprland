import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: contentColumn.implicitWidth

    property int defaultSeconds: 300
    property int baseTargetSeconds: defaultSeconds 
    property int targetSeconds: baseTargetSeconds 
    property int secondsLeft: baseTargetSeconds
    property bool isRunning: false
    property real startTimestamp: 0

    Timer {
        id: tickTimer
        interval: 200 
        running: root.isRunning
        repeat: true
        onTriggered: {
            let current = Math.floor(Date.now() / 1000);
            let elapsed = current - root.startTimestamp;
            root.secondsLeft = Math.max(0, root.targetSeconds - elapsed);

            if (root.secondsLeft === 0) {
                root.isRunning = false;
                
                // 1. Send the desktop notification
                Quickshell.execDetached(["notify-send", "Timer", Translation.tr("Countdown finished!"), "-a", "Shell"]);
                
                // 2. Play the trilling sound 
                if (Config.options.sounds.timer) {
                    Audio.playSystemSound("complete");
                }
            }
        }
    }

    function toggleCountdown() {
        if (root.isRunning) {
            root.targetSeconds = root.secondsLeft;
            root.isRunning = false;
        } else {
            if (root.secondsLeft <= 0) return;
            root.startTimestamp = Math.floor(Date.now() / 1000);
            root.isRunning = true;
        }
    }

    function clearCountdown() {
        root.isRunning = false;
        root.targetSeconds = root.baseTargetSeconds;
        root.secondsLeft = root.baseTargetSeconds;
    }

    function resetCountdown() {
        root.isRunning = false;
        root.baseTargetSeconds = root.defaultSeconds 
        root.targetSeconds = root.defaultSeconds;
        root.secondsLeft = root.defaultSeconds;
    }

    function adjustTime(secondsOffset) {
        if (root.isRunning) return; 
        let newTime = root.baseTargetSeconds + secondsOffset;
        
        root.baseTargetSeconds = Math.max(0, newTime); 
        root.targetSeconds = root.baseTargetSeconds;
        root.secondsLeft = root.baseTargetSeconds;
    }

    // New function to handle manual text box typing
    function setExactTime(m, s) {
        if (root.isRunning) return;
        let newTime = Math.max(0, (m * 60) + s);
        root.baseTargetSeconds = newTime;
        root.targetSeconds = root.baseTargetSeconds;
        root.secondsLeft = root.baseTargetSeconds;
        
        // Remove focus from text boxes so they update visually
        root.forceActiveFocus(); 
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: 15

        CircularProgress {
            Layout.alignment: Qt.AlignHCenter
            lineWidth: 8
            value: root.targetSeconds > 0 ? (root.secondsLeft / root.targetSeconds) : 0
            implicitSize: 200
            enableAnimation: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 2

                    // --- Minutes Editable Text Box ---
                    TextInput {
                        id: minInput
                        text: Math.floor(root.secondsLeft / 60).toString().padStart(2, '0')
                        font.pixelSize: 40
                        color: Appearance.m3colors.m3onSurface
                        enabled: !root.isRunning
                        selectByMouse: true
                        selectionColor: Appearance.colors.colPrimary
                        
                        maximumLength: 3 // Allows up to 999 minutes
                        validator: RegularExpressionValidator { regularExpression: /^[0-9]*$/ }
                        
                        onEditingFinished: {
                            let parsed = parseInt(text);
                            let m = isNaN(parsed) ? 0 : parsed; 
                            let s = Math.floor(root.secondsLeft % 60);
                            
                            root.setExactTime(m, s);
                            minInput.text = Qt.binding(() => Math.floor(root.secondsLeft / 60).toString().padStart(2, '0'));
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton 
                            cursorShape: minInput.activeFocus ? Qt.IBeamCursor : (enabled ? Qt.SizeVerCursor : Qt.ArrowCursor)
                            
                            onWheel: (wheel) => {
                                minInput.focus = false; 
                                if (wheel.angleDelta.y > 0) root.adjustTime(60); 
                                else root.adjustTime(-60);
                            }
                        }
                    }

                    // --- Colon Separator ---
                    StyledText {
                        text: ":"
                        font.pixelSize: 40
                        color: Appearance.m3colors.m3onSurface
                    }

                    // --- Seconds Editable Text Box ---
                    TextInput {
                        id: secInput
                        text: Math.floor(root.secondsLeft % 60).toString().padStart(2, '0')
                        font.pixelSize: 40
                        color: Appearance.m3colors.m3onSurface
                        enabled: !root.isRunning
                        selectByMouse: true
                        selectionColor: Appearance.colors.colPrimary
                        
                        // FIX: Strictly limit to exactly 2 characters
                        maximumLength: 2 
                        validator: RegularExpressionValidator { regularExpression: /^[0-9]*$/ }
                        
                        onEditingFinished: {
                            let m = Math.floor(root.secondsLeft / 60);
                            
                            // FIX: Safely fallback to 0
                            let parsed = parseInt(text);
                            let s = isNaN(parsed) ? 0 : parsed;
                            
                            root.setExactTime(m, s);
                            secInput.text = Qt.binding(() => Math.floor(root.secondsLeft % 60).toString().padStart(2, '0'));
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton 
                            cursorShape: secInput.activeFocus ? Qt.IBeamCursor : (enabled ? Qt.SizeVerCursor : Qt.ArrowCursor)
                            
                            onWheel: (wheel) => {
                                secInput.focus = false;
                                if (wheel.angleDelta.y > 0) root.adjustTime(1); 
                                else root.adjustTime(-1);
                            }
                        }
                    }
                }
                
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Countdown")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }
            }
        }

        // Expanded Time Customization Controls
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            visible: !root.isRunning 
            opacity: visible ? 1 : 0

            component AdjustButton : RippleButton {
                property int timeOffset: 0
                property string labelText: ""
                
                implicitHeight: 30
                implicitWidth: 40
                colBackground: Appearance.colors.colLayer2
                onClicked: root.adjustTime(timeOffset)
                contentItem: StyledText {
                    anchors.centerIn: parent
                    text: parent.labelText
                    color: Appearance.colors.colOnLayer2
                }
            }

            AdjustButton { labelText: "-1m"; timeOffset: -60 }
            AdjustButton { labelText: "+1m"; timeOffset: 60 }
            AdjustButton { labelText: "+5m"; timeOffset: 300 }
            AdjustButton { labelText: "+10m"; timeOffset: 600 }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            RippleButton {
                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: root.isRunning ? Translation.tr("Pause") : (root.secondsLeft === root.targetSeconds && root.secondsLeft > 0 ? Translation.tr("Start") : Translation.tr("Resume"))
                    color: root.isRunning ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary
                }
                implicitHeight: 35
                implicitWidth: 90
                font.pixelSize: Appearance.font.pixelSize.larger
                onClicked: root.toggleCountdown()
                enabled: root.secondsLeft > 0 || root.isRunning
                colBackground: root.isRunning ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimary
                colBackgroundHover: root.isRunning ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimary
            }

            RippleButton {
                implicitHeight: 35
                implicitWidth: 90
                onClicked: root.isRunning ? root.clearCountdown() : root.resetCountdown()
                enabled: true

                font.pixelSize: Appearance.font.pixelSize.larger
                colBackground: Appearance.colors.colErrorContainer
                colBackgroundHover: Appearance.colors.colErrorContainerHover
                colRipple: Appearance.colors.colErrorContainerActive

                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text:  root.isRunning ? Translation.tr("Clear") : Translation.tr("Reset")
                    color: Appearance.colors.colOnErrorContainer
                }
            }
        }
    }
}