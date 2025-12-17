import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.modules.common
import qs.modules.common.widgets
import qs.services

Window {
    id: rootWindow
    width: 580 
    height: 260
    visible: false 
    title: "Monitor Risorse"
    
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"

    property int currentTab: 0

    // --- SFONDO E LAYOUT ---
    Rectangle {
        id: mainBackground
        anchors.fill: parent
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.windowRounding
        border.color: Appearance.colors.colOutlineVariant
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 10

            // 1. Titolo
            Text {
                text: "Monitor Risorse"
                color: Appearance.colors.colOnSurface
                font.bold: true
                font.pixelSize: Appearance.font.pixelSize.large
                font.family: Appearance.font.family.title
                Layout.alignment: Qt.AlignHCenter 
            }

            // 2. Tab Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MonitorTabButton { 
                    label: "CPU"; icon: "earthquake"; isActive: currentTab === 0
                    onClicked: currentTab = 0
                }
                MonitorTabButton { 
                    label: "RAM"; icon: "memory"; isActive: currentTab === 1
                    onClicked: currentTab = 1
                }
                MonitorTabButton { 
                    label: "Temp"; icon: "device_thermostat"; isActive: currentTab === 2
                    onClicked: currentTab = 2
                }
                MonitorTabButton { 
                    label: "Fan"; icon: "mode_fan"; isActive: currentTab === 3
                    onClicked: currentTab = 3
                }
            }

            // 3. Contenuto
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: {
                    switch(rootWindow.currentTab) {
                        case 0: return cpuGraphComp
                        case 1: return ramGraphComp
                        case 2: return tempGraphComp
                        case 3: return fanGraphComp
                        default: return cpuGraphComp
                    }
                }
            }
        }
    }

    // --- DEFINIZIONE DATI (Models) ---

    // 1. CPU GRAPH COMPONENT
    Component {
        id: cpuGraphComp
        ResourceGraph {
            readonly property real currentUsage: ResourceUsage.cpuUsage
            property real stableScale: 0.20
            
            // Logica: Cerca il valore MAX in tutta la history visibile
            onCurrentUsageChanged: {
                // Recupera il massimo storico attuale o il valore corrente
                let maxHistory = Math.max(...ResourceUsage.cpuUsageHistory, currentUsage)
                
                // Calcola lo step basandosi sul picco storico
                let step = Math.ceil((maxHistory * 1.1) / 0.2) * 0.2
                
                // Imposta la scala (minimo 0.2, massimo 1.0)
                stableScale = Math.max(0.2, Math.min(1.0, step))
            }
            
            maximumValue: stableScale
            seriesData: [{ 
                label: "CPU Totale", 
                color: currentUsage > 0.8 ? Appearance.m3colors.m3error : Appearance.m3colors.term2, 
                valueText: (currentUsage * 100).toFixed(1) + "%", 
                data: ResourceUsage.cpuUsageHistory 
            }]
        }
    }

    // 2. RAM GRAPH COMPONENT
    Component {
        id: ramGraphComp
        ResourceGraph {
            readonly property real currentUsage: ResourceUsage.memoryUsedPercentage
            property real stableScale: 0.20
            
            // Logica: Cerca il valore MAX in tutta la history visibile
            onCurrentUsageChanged: {
                let maxHistory = Math.max(...ResourceUsage.memoryUsageHistory, currentUsage)
                
                let step = Math.ceil((maxHistory * 1.1) / 0.2) * 0.2
                stableScale = Math.max(0.2, Math.min(1.0, step))
            }
            
            maximumValue: stableScale
            seriesData: [{ 
                label: "RAM Usata", 
                color: Appearance.m3colors.term14, 
                valueText: ResourceUsage.kbToGbString(ResourceUsage.memoryUsed), 
                data: ResourceUsage.memoryUsageHistory 
            }]
        }
    }

    // 3. TEMP GRAPH COMPONENT
    Component {
        id: tempGraphComp
        ResourceGraph {
            readonly property real currentTemp: ResourceUsage.cpuTemperature
            property real stableScale: 90
            
            // Logica: Scala basata sul picco storico
            onCurrentTempChanged: {
                let maxHistory = Math.max(...ResourceUsage.tempHistory, currentTemp)
                
                // Se il massimo storico supera la scala base (90), alza la scala
                if (maxHistory > 90) {
                     stableScale = Math.ceil((maxHistory + 5) / 10) * 10
                } else {
                     stableScale = 90
                }
            }
            
            maximumValue: stableScale
            seriesData: [{ 
                label: "Package", 
                color: Appearance.m3colors.term11, 
                valueText: currentTemp.toFixed(0) + "°C", 
                data: ResourceUsage.tempHistory 
            }]
        }
    }

    // 4. FAN GRAPH COMPONENT
    Component {
        id: fanGraphComp
        ResourceGraph {
            // Monitoriamo i picchi correnti
            readonly property int currentPeak: Math.max(ResourceUsage.fan1RPM, ResourceUsage.fan2RPM)
            property int stableScale: 4000
            
            // Logica: Controlla entrambe le history per trovare il picco assoluto
            onCurrentPeakChanged: {
                // Trova il max nelle due history
                let maxFan1 = Math.max(...ResourceUsage.fan1History, 0)
                let maxFan2 = Math.max(...ResourceUsage.fan2History, 0)
                
                // Il massimo assoluto tra history e valore corrente
                let globalMax = Math.max(maxFan1, maxFan2, currentPeak)

                // Calcola scala con buffer del 20%, step di 1000 RPM
                let step = Math.max(4000, Math.ceil((globalMax * 1.2) / 1000) * 1000)
                
                stableScale = step
            }
            
            maximumValue: stableScale
            seriesData: [
                { label: "Ventola 1", color: Appearance.m3colors.term12, valueText: ResourceUsage.fan1RPM + "", data: ResourceUsage.fan1History },
                { label: "Ventola 2", color: Appearance.m3colors.term6, valueText: ResourceUsage.fan2RPM + "", data: ResourceUsage.fan2History }
            ]
        }
    }
}