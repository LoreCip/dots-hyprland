import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

StyledPopup {
    id: root

    // Proprietà di supporto per l'estetica
    readonly property string iface: NetworkSpeed.activeInterface
    readonly property bool isWifi: iface.startsWith("w")
    readonly property string mainIcon: isWifi ? "wifi" : (iface.startsWith("e") ? "settings_ethernet" : "cloud_off")

    Item {
        id: container
    
        implicitWidth: 320 
        implicitHeight: columnContent.height + 30 

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: root.keepOpen = containsMouse
        }

        Column {
            id: columnContent
            width: parent.width - 20
            anchors.centerIn: parent
            spacing: 16

            // --- HEADER: Stato Interfaccia ---
            Row {
                width: parent.width
                spacing: 10
                
                Text {
                    text: iface !== "none" ? "Connesso via " + (root.isWifi ? "Wi-Fi" : "Ethernet") : "Disconnesso"
                    color: Appearance.colors.colOnSurface
                    font: Appearance.font.variableAxes.main
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // --- CONTENUTO: Download & Upload ---
            Column {
                width: parent.width
                spacing: 12

                // Riga Download
                NetworkRow {
                    label: "Download"
                    speedStr: NetworkSpeed.downloadSpeedStr
                    speedValue: NetworkSpeed.downloadSpeed
                    icon: "download"
                    activeColor: Appearance.m3colors.m3success
                }

                // Riga Upload
                NetworkRow {
                    label: "Upload"
                    speedStr: NetworkSpeed.uploadSpeedStr
                    speedValue: NetworkSpeed.uploadSpeed
                    icon: "upload"
                    activeColor: Appearance.m3colors.m3tertiary
                }
            }
        }
    }

    // Componente interno per evitare ripetizioni
    component NetworkRow : Item {
        property string label
        property string speedStr
        property real speedValue
        property string icon
        property color activeColor

        width: parent.width
        height: 35

        Row {
            anchors.fill: parent
            spacing: 8
            
            MaterialSymbol {
                text: icon
                iconSize: 22
                color: Appearance.colors.colOnSurfaceVariant
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - 90 
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    text: label
                    color: Appearance.colors.colOnSurface
                    font: Appearance.font.variableAxes.main
                }
                
                // Barra di attività
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Appearance.colors.colSurfaceContainerHighest

                    Rectangle {
                        height: parent.height
                        width: {
                            if (speedValue <= 0) return 0;
                            
                            let maxLog = 8.5; 
                            let currentLog = Math.log10(speedValue + 1);
                            
                            let percent = Math.min(currentLog / maxLog, 1.0);
                            
                            return parent.width * percent;
                        }

                        color: activeColor
                        radius: 2
                        
                        Behavior on width { 
                            NumberAnimation { duration: 350; easing.type: Easing.OutQuart } 
                        }
                    }
                }
            }
            
            Text {
                text: speedStr
                color: Appearance.colors.colOnSurface
                font: Appearance.font.variableAxes.numbers
                anchors.verticalCenter: parent.verticalCenter
                width: 60
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}