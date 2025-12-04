import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets

IconToolbarButton {
    id: root
    
    property int jobCount: 0
    visible: jobCount > 0
    
    text: "print"
    
    Process {
        id: checkQueue
        command: ["bash", "-c", "lpstat -o | wc -l"]
        
        stdout: SplitParser {
            onRead: (data) => {
                var count = parseInt(data.trim());
                root.jobCount = isNaN(count) ? 0 : count;
            }
        }
    }

    // === TIMER ===
    Timer {
        interval: 1000 
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: checkQueue.running = true
    }

    onClicked: {
        Quickshell.execDetached(["system-config-printer", "--show-jobs", "BrotherWiFi"]) 
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow
        acceptedButtons: Qt.NoButton
        
        PrinterIndicatorPopup {
            hoverTarget: mouseArea
            jobCount: root.jobCount
        }
    }
}