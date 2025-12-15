import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Window {
    id: rootWindow
    width: 400
    height: 180
    visible: false
    title: "Monitor Risorse"
    
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"

    property int currentTab: 0

    // --- 1. COMPONENTE GRAFICO BASE ---
    component ResourceGraph: Item {
        id: graphRoot
        property var seriesData: [] 
        property real maximumValue: 1.0

        Layout.fillWidth: true
        Layout.fillHeight: true

        Component.onCompleted: graphCanvas.requestPaint()
        onSeriesDataChanged: graphCanvas.requestPaint()

        Rectangle {
            anchors.fill: parent; color: "#2d2d2d"; radius: 4; border.color: "#3d3d3d"; border.width: 1

            // --- HEADER (Legenda Allineata a DESTRA) ---
            RowLayout {
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                anchors.margins: 10; height: 20; z: 10; spacing: 15
                
                // 1. Spaziatore a sinistra: Spinge tutto il resto a destra
                Item { Layout.fillWidth: true } 

                // 2. Legenda (Ora a destra)
                RowLayout {
                    spacing: 15
                    Repeater {
                        model: graphRoot.seriesData
                        RowLayout {
                            spacing: 5
                            Rectangle { width: 8; height: 8; radius: 4; color: modelData.color }
                            // Nome Serie
                            Text { text: modelData.label; color: "#cccccc"; font.pixelSize: 12 }
                            // Valore
                            Text { 
                                text: modelData.valueText
                                color: "white"; font.bold: true; font.pixelSize: 12 
                                // Monospace per evitare che i numeri "ballino" troppo
                                font.family: "Monospace" 
                            }
                        }
                    }
                }
            }

            // Plot Area
            Item {
                id: plotArea
                anchors.top: parent.top; anchors.bottom: parent.bottom
                anchors.left: parent.left; anchors.right: parent.right
                anchors.topMargin: 35; anchors.bottomMargin: 25
                anchors.leftMargin: 10; anchors.rightMargin: 10
                
                // Griglia
                Repeater {
                    model: 5 
                    Item {
                        width: parent.width; height: 1
                        y: Math.floor(index * (plotArea.height / 4))
                        Rectangle { width: parent.width; height: 1; color: "#3d3d3d"; opacity: 0.5 }
                        Text {
                            anchors.bottom: parent.top; anchors.left: parent.left; anchors.bottomMargin: 2
                            color: "#888"; font.pixelSize: 10
                            text: {
                                let step = graphRoot.maximumValue / 4
                                let val = graphRoot.maximumValue - (index * step)
                                return graphRoot.maximumValue <= 1.0 ? (val * 100).toFixed(0) + "%" : val.toFixed(0)
                            }
                        }
                    }
                }

                // Canvas
                Canvas {
                    id: graphCanvas
                    anchors.fill: parent
                    antialiasing: true; smooth: false 
                    renderTarget: Canvas.FramebufferObject; renderStrategy: Canvas.Threaded

                    onPaint: {
                        var ctx = getContext("2d");
                        var w = width; var h = height;
                        ctx.reset(); ctx.clearRect(0, 0, w, h);
                        ctx.lineJoin = "round"; ctx.lineWidth = 2;

                        var seriesList = graphRoot.seriesData;
                        if (!seriesList || seriesList.length === 0) return;
                        var len = seriesList.length;

                        for (var s = 0; s < len; s++) {
                            var series = seriesList[s];
                            var data = series.data;
                            if (!data || data.length < 2) continue;
                            var count = data.length;
                            var stepX = w / (count - 1);
                            var scaleFactor = h / graphRoot.maximumValue; 
                            var color = series.color || "#ffffff";

                            // Fill
                            ctx.beginPath(); ctx.moveTo(0, h);
                            var i, x, val;
                            for (i = 0; i < count; i++) {
                                val = data[i] * scaleFactor; if (val > h) val = h; else if (val < 0) val = 0;
                                x = ~~(i * stepX); ctx.lineTo(x, ~~(h - val));
                            }
                            ctx.lineTo(w, h); ctx.closePath();
                            ctx.save(); 
                            var grad = ctx.createLinearGradient(0, 0, 0, h);
                            grad.addColorStop(0, color); grad.addColorStop(1, "transparent"); 
                            ctx.globalAlpha = 0.25; ctx.fillStyle = grad; ctx.fill();
                            ctx.restore(); 

                            // Stroke
                            ctx.beginPath();
                            val = data[0] * scaleFactor; if (val > h) val = h; else if (val < 0) val = 0;
                            ctx.moveTo(0, ~~(h - val));
                            for (i = 1; i < count; i++) {
                                val = data[i] * scaleFactor; if (val > h) val = h; else if (val < 0) val = 0;
                                ctx.lineTo(~~(i * stepX), ~~(h - val));
                            }
                            ctx.strokeStyle = color; ctx.stroke();
                        }
                    }
                }

                // Tooltip
                MouseArea {
                    id: hoverArea; anchors.fill: parent; hoverEnabled: true 
                    property int hoveredIndex: -1
                    onPositionChanged: (mouse) => {
                        if (graphRoot.seriesData.length > 0 && graphRoot.seriesData[0].data.length > 0) {
                            let count = graphRoot.seriesData[0].data.length
                            let stepX = width / (count - 1)
                            hoveredIndex = Math.max(0, Math.min(Math.round(mouse.x / stepX), count - 1))
                        }
                    }
                    onExited: hoveredIndex = -1

                    Rectangle {
                        id: cursorLine
                        visible: hoverArea.hoveredIndex >= 0
                        width: 1; height: parent.height; y: 0; color: "white"; opacity: 0.5
                        x: {
                            if (graphRoot.seriesData.length === 0) return 0
                            let count = graphRoot.seriesData[0].data.length
                            return hoverArea.hoveredIndex * (parent.width / (count - 1))
                        }
                    }
                    Rectangle {
                        visible: hoverArea.hoveredIndex >= 0
                        x: {
                            let lineX = cursorLine.x
                            if (lineX > parent.width / 2) return lineX - width - 10 
                            else return lineX + 10 
                        }
                        y: 10 
                        width: tooltipCol.implicitWidth + 20; height: tooltipCol.implicitHeight + 16
                        color: "#252525"; border.color: "#555"; radius: 4; layer.enabled: true
                        
                        ColumnLayout {
                            id: tooltipCol; anchors.centerIn: parent; spacing: 4
                            Repeater {
                                model: graphRoot.seriesData
                                RowLayout {
                                    spacing: 8
                                    Rectangle { width: 6; height: 6; radius: 3; color: modelData.color }
                                    Text { text: modelData.label; color: "#ccc"; font.pixelSize: 11 }
                                    Text {
                                        color: "white"; font.bold: true; font.pixelSize: 11
                                        text: {
                                            let idx = hoverArea.hoveredIndex
                                            if (idx >= 0 && modelData.data && idx < modelData.data.length) {
                                                let val = modelData.data[idx]
                                                if (graphRoot.maximumValue <= 1.0) return (val * 100).toFixed(1) + "%"
                                                else return val.toFixed(0)
                                            }
                                            return "--"
                                        }
                                    }
                                }
                            }
                        }
                    }
                } 
            } 
            
            // --- FOOTER (Asse X Aggiornato) ---
            RowLayout {
                anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 10; anchors.rightMargin: 10; anchors.bottomMargin: 5
                
                Text { text: "60s"; color: "#666"; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: "30s"; color: "#666"; font.pixelSize: 10 } // <-- Tick aggiunto
                Item { Layout.fillWidth: true }
                Text { text: "Now"; color: "#666"; font.pixelSize: 10 }
            }
        }
    }

    // --- 2. DEFINIZIONE DEI COMPONENTI ---
    Component {
        id: cpuGraph
        ResourceGraph {
            readonly property real currentUsage: ResourceUsage.cpuUsage
            property real stableScale: 0.20
            onCurrentUsageChanged: {
                let step = Math.ceil((currentUsage * 1.1) / 0.2) * 0.2
                stableScale = Math.max(0.2, Math.min(1.0, Math.max(stableScale, step)))
                if (step < stableScale && currentUsage < (stableScale - 0.15)) stableScale = step
            }
            maximumValue: stableScale
            seriesData: [{ label: "CPU Totale", color: currentUsage > 0.8 ? "#ff5555" : "#33c481", valueText: (currentUsage * 100).toFixed(1) + "%", data: ResourceUsage.cpuUsageHistory }]
        }
    }

    Component {
        id: ramGraph
        ResourceGraph {
            readonly property real currentUsage: ResourceUsage.memoryUsedPercentage
            property real stableScale: 0.20
            onCurrentUsageChanged: {
                let step = Math.ceil((currentUsage * 1.1) / 0.2) * 0.2
                stableScale = Math.max(0.2, Math.min(1.0, Math.max(stableScale, step)))
                if (step < stableScale && currentUsage < (stableScale - 0.15)) stableScale = step
            }
            maximumValue: stableScale
            seriesData: [{ label: "RAM Usata", color: "#a371f7", valueText: ResourceUsage.kbToGbString(ResourceUsage.memoryUsed), data: ResourceUsage.memoryUsageHistory }]
        }
    }

    Component {
        id: tempGraph
        ResourceGraph {
            readonly property real currentTemp: ResourceUsage.cpuTemperature
            property real stableScale: 90
            onCurrentTempChanged: {
                if (currentTemp > stableScale) stableScale = Math.ceil(currentTemp / 10) * 10
                else if (stableScale > 90 && currentTemp < stableScale - 15) stableScale = Math.max(90, Math.ceil((currentTemp + 5) / 10) * 10)
            }
            maximumValue: stableScale
            seriesData: [{ label: "Package", color: "#ff6b6b", valueText: currentTemp.toFixed(0) + "°C", data: ResourceUsage.tempHistory }]
        }
    }

    Component {
        id: fanGraph
        ResourceGraph {
            readonly property int currentPeak: Math.max(ResourceUsage.fan1RPM, ResourceUsage.fan2RPM)
            property int stableScale: 4000
            onCurrentPeakChanged: {
                let step = Math.max(4000, Math.ceil((currentPeak * 1.2) / 1000) * 1000)
                if (step > stableScale) stableScale = step
                else if (step < stableScale * 0.75) stableScale = step
            }
            maximumValue: stableScale
            seriesData: [
                { label: "Ventola 1", color: "#f7b171", valueText: ResourceUsage.fan1RPM + "", data: ResourceUsage.fan1History },
                { label: "Ventola 2", color: "#4fbbfd", valueText: ResourceUsage.fan2RPM + "", data: ResourceUsage.fan2History }
            ]
        }
    }

    // --- LAYOUT PRINCIPALE ---
    Rectangle {
        id: mainBackground
        anchors.fill: parent
        color: "#1e1e1e"
        radius: 10
        border.color: "#444444"
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 10

            // Titolo
            Text {
                text: "Monitor Risorse"
                color: "white"
                font.bold: true
                font.pixelSize: 16
                Layout.alignment: Qt.AlignHCenter 
            }

            // Tabs con il tuo MaterialSymbols.qml
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                component TabButton: Rectangle {
                    id: btn
                    property string label: ""
                    property string icon: "" 
                    property int tabIndex: 0
                    property bool isActive: rootWindow.currentTab === tabIndex
                    
                    Layout.fillWidth: true
                    height: 36
                    radius: 18 // Pill shape
                    
                    color: isActive ? "#4a4458" : "#252525"
                    border.color: isActive ? "#d0bcff" : "#333"
                    border.width: 1

                    scale: tapHandler.pressed ? 0.96 : 1.0
                    Behavior on scale { NumberAnimation { duration: 50 } }
                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8 
                        
                        MaterialSymbol{
                            text: btn.icon
                            fill: btn.isActive ? 1 : 0
                            iconSize: 20 
                            color: btn.isActive ? "#d0bcff" : "#888"
                        }
                        
                        Text {
                            text: btn.label
                            color: btn.isActive ? "#e6e1e5" : "#888"
                            font.bold: btn.isActive
                            font.pixelSize: 12
                        }
                    }

                    TapHandler {
                        id: tapHandler
                        onTapped: rootWindow.currentTab = btn.tabIndex
                    }
                }

                // Codici Unicode
                TabButton { label: "CPU";  icon: "earthquake"; tabIndex: 0 } 
                TabButton { label: "RAM";  icon: "memory"; tabIndex: 1 } 
                TabButton { label: "Temp"; icon: "device_thermostat"; tabIndex: 2 } 
                TabButton { label: "Fan";  icon: "mode_fan"; tabIndex: 3 } 
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: {
                    switch(rootWindow.currentTab) {
                        case 0: return cpuGraph
                        case 1: return ramGraph
                        case 2: return tempGraph
                        case 3: return fanGraph
                        default: return cpuGraph
                    }
                }
            }
        }
    }
}