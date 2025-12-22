import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

// Eredita dal tuo StyledPopup personalizzato
StyledPopup {
    id: root

    Item {
        id: container
    
        // 1. Qui definiamo la grandezza del popup
        implicitWidth: 320 
        implicitHeight: columnDevices.height + 20 // 15px padding sopra e sotto

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: root.keepOpen = containsMouse
        }

        Column {
            id: columnDevices
            width: parent.width
            anchors.centerIn: parent // Centra la colonna nel popup
            spacing: 12 // Più spazio tra un dispositivo e l'altro

            Repeater {
                model: BluetoothStatus.deviceList
                delegate: Item {
                    // 2. Altezza fissa per ogni riga per dare "aria"
                    width: container.width - 20 // Padding laterale (10px per lato)
                    height: 35 
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Row {
                        anchors.fill: parent
                        spacing: 5
                        
                        // Icona (Centrata verticalmente)
                        MaterialSymbol {
                            text: modelData.icon
                            iconSize: 24 // Icona più grande
                            color: Appearance.colors.colOnSurface
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Colonna Centrale (Nome + Barra)
                        Column {
                            // Occupa tutto lo spazio disponibile tra icona e percentuale
                            width: parent.width - 70 
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            // Nome Dispositivo
                            Text {
                                text: modelData.name
                                color: Appearance.colors.colOnSurface
                                font: Appearance.font.variableAxes.main
                                elide: Text.ElideRight
                                width: parent.width
                                horizontalAlignment: Text.AlignLeft
                            }
                            
                            // Barra Batteria
                            Rectangle {
                                width: parent.width
                                height: 6 // Barra più spessa
                                radius: 3
                                color: Appearance.colors.colSurfaceContainerHighest

                                anchors.left: parent.left

                                Rectangle {
                                    height: parent.height
                                    width: Math.max(parent.width * (modelData.percent / 100), 4) // Minimo 4px per vederla
                                    color: modelData.color
                                    radius: 3
                                    
                                    // Animazione carina sul cambio percentuale
                                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                        
                        // Percentuale (A destra)
                        Text {
                            text: modelData.percent + "%"
                            color: Appearance.colors.colOnSurfaceVariant
                            font: Appearance.font.variableAxes.numbers
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }
        }
    }
}