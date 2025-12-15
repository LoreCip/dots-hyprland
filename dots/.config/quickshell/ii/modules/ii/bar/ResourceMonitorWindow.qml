import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes

import qs.modules.common
import qs.services

Window {
    id: rootWindow
    width: 400
    height: 550 // Altezza fissa per abilitare lo scroll
    visible: false 
    title: "Monitor Risorse"

    // Flags per finestra floating senza bordi OS (necessario per il layout custom)
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"

    component ResourceGraph: Item {
        id: graphRoot
        property string title: ""
        property var seriesData: [] 
        property real maximumValue: 1.0

        Layout.fillWidth: true
        Layout.preferredHeight: 200

        // Quando i dati cambiano, ridisegna il canvas
        onSeriesDataChanged: graphCanvas.requestPaint()

        Rectangle {
            anchors.fill: parent
            color: "#2d2d2d"
            radius: 4
            border.color: "#3d3d3d"
            border.width: 1

            // --- HEADER ---
            RowLayout {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                height: 20
                z: 10 
                spacing: 15
                
                Text {
                    text: graphRoot.title
                    color: "white"
                    font.bold: true
                    font.pixelSize: 14
                    Layout.alignment: Qt.AlignVCenter
                }
                Item { Layout.fillWidth: true } 
                RowLayout {
                    spacing: 15
                    Repeater {
                        model: graphRoot.seriesData
                        RowLayout {
                            spacing: 5
                            Rectangle { width: 8; height: 8; radius: 4; color: modelData.color }
                            Text { text: modelData.label; color: "#cccccc"; font.pixelSize: 12 }
                            Text { text: modelData.valueText; color: "white"; font.bold: true; font.pixelSize: 12 }
                        }
                    }
                }
            }

            // --- AREA PLOT ---
            Item {
                id: plotArea
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 45
                anchors.bottomMargin: 25
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                
                // 1. GRIGLIA SFONDO
                Repeater {
                    model: 5 
                    Item {
                        width: parent.width; height: 1
                        y: Math.floor(index * (plotArea.height / 4))
                        Rectangle { width: parent.width; height: 1; color: "#3d3d3d"; opacity: 0.5 }
                        Text {
                            anchors.bottom: parent.top; anchors.left: parent.left; anchors.bottomMargin: 2
                            color: "#888888"; font.pixelSize: 10
                            text: {
                                let step = graphRoot.maximumValue / 4
                                let val = graphRoot.maximumValue - (index * step)
                                return graphRoot.maximumValue <= 1.0 ? (val * 100).toFixed(0) + "%" : val.toFixed(0)
                            }
                        }
                    }
                }

                // 2. CANVAS OTTIMIZZATO (TURBO MODE)
                Canvas {
                    id: graphCanvas
                    anchors.fill: parent
                    
                    antialiasing: true 
                    smooth: false 

                    renderTarget: Canvas.FramebufferObject 
                    renderStrategy: Canvas.Threaded

                    property bool shouldDraw: rootWindow.visible
                    onShouldDrawChanged: if (shouldDraw) requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        var w = width; 
                        var h = height;
                        
                        ctx.reset();
                        ctx.clearRect(0, 0, w, h);
                        
                        ctx.lineJoin = "round"; 
                        ctx.lineWidth = 2;

                        var seriesList = graphRoot.seriesData;
                        if (!seriesList || seriesList.length === 0) return;
                        var len = seriesList.length;

                        for (var s = 0; s < len; s++) {
                            var series = seriesList[s];
                            var data = series.data;
                            
                            if (!data) continue;
                            var count = data.length;
                            if (count < 2) continue;

                            var stepX = w / (count - 1);
                            var scaleFactor = h / graphRoot.maximumValue; 
                            var color = series.color || "#ffffff";

                            // Fill
                            ctx.beginPath();
                            ctx.moveTo(0, h);
                            
                            var i, x, val, y;
                            for (i = 0; i < count; i++) {
                                val = data[i] * scaleFactor;
                                if (val > h) val = h; else if (val < 0) val = 0;
                                x = ~~(i * stepX);
                                y = ~~(h - val);
                                ctx.lineTo(x, y);
                            }
                            
                            ctx.lineTo(w, h);
                            ctx.closePath();
                            
                            ctx.save(); 
                            var grad = ctx.createLinearGradient(0, 0, 0, h);
                            grad.addColorStop(0, color);         
                            grad.addColorStop(1, "transparent"); 
                            ctx.globalAlpha = 0.25; 
                            ctx.fillStyle = grad;
                            ctx.fill();
                            ctx.restore(); 

                            // Stroke
                            ctx.beginPath();
                            val = data[0] * scaleFactor;
                            if (val > h) val = h; else if (val < 0) val = 0;
                            ctx.moveTo(0, ~~(h - val));

                            for (i = 1; i < count; i++) {
                                val = data[i] * scaleFactor;
                                if (val > h) val = h; else if (val < 0) val = 0;
                                x = ~~(i * stepX);
                                y = ~~(h - val);
                                ctx.lineTo(x, y);
                            }
                            
                            ctx.strokeStyle = color; 
                            ctx.stroke();
                        }
                    }
                }

                // 3. INTERATTIVITÀ TOOLTIP
                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true 
                    
                    property int hoveredIndex: -1
                    property bool isHovering: containsMouse

                    onPositionChanged: (mouse) => {
                        if (graphRoot.seriesData.length > 0 && graphRoot.seriesData[0].data.length > 0) {
                            let count = graphRoot.seriesData[0].data.length
                            let stepX = width / (count - 1)
                            let idx = Math.round(mouse.x / stepX)
                            if (idx < 0) idx = 0
                            if (idx >= count) idx = count - 1
                            hoveredIndex = idx
                        }
                    }

                    onExited: hoveredIndex = -1

                    Rectangle {
                        id: cursorLine
                        visible: hoverArea.isHovering && hoverArea.hoveredIndex >= 0
                        width: 1; height: parent.height; y: 0; color: "white"; opacity: 0.5
                        x: {
                            if (graphRoot.seriesData.length === 0) return 0
                            let count = graphRoot.seriesData[0].data.length
                            return hoverArea.hoveredIndex * (parent.width / (count - 1))
                        }
                    }

                    Rectangle {
                        id: tooltipBox
                        visible: hoverArea.isHovering && hoverArea.hoveredIndex >= 0
                        x: {
                            let lineX = cursorLine.x
                            if (lineX > parent.width / 2) return lineX - width - 10 
                            else return lineX + 10 
                        }
                        y: 10 
                        width: tooltipLayout.implicitWidth + 20
                        height: tooltipLayout.implicitHeight + 16
                        color: "#252525"; border.color: "#555"; radius: 4
                        layer.enabled: true
                        
                        ColumnLayout {
                            id: tooltipLayout
                            anchors.centerIn: parent
                            spacing: 4

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

            RowLayout {
                anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 10; anchors.rightMargin: 10; anchors.bottomMargin: 5
                Text { text: "60s"; color: "#666"; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: "30s"; color: "#666"; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: "Now"; color: "#666"; font.pixelSize: 10 }
            }
        }
    }

    // --- STRUTTURA PER LO SCROLL ---
    Rectangle {
        id: mainBackground
        anchors.fill: parent
        color: "#1e1e1e"
        radius: 10
        border.color: "#444444"
        border.width: 1
        clip: true

        // Header Fisso
        Text {
            id: windowTitle
            text: "Monitor Risorse"
            color: "white"
            font.bold: true
            font.pixelSize: 16
            
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 15
            height: 30
        }

        // Area Scorrevole
        ScrollView {
            id: scrollView
            
            anchors.top: windowTitle.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            anchors.bottomMargin: 15
            
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: scrollView.availableWidth
                spacing: 15

                ResourceGraph {
                    title: "CPU"
                    readonly property real currentUsage: ResourceUsage.cpuUsage
                    property real stableScale: 0.20
                    onCurrentUsageChanged: {
                        let rawTarget = currentUsage * 1.1    
                        let stepTarget = Math.ceil(rawTarget / 0.20) * 0.20
                        if (stepTarget < 0.20) stepTarget = 0.20
                        if (stepTarget > 1.0) stepTarget = 1.0
                        if (stepTarget > stableScale) stableScale = stepTarget
                        else if (stepTarget < stableScale && currentUsage < (stableScale - 0.15)) stableScale = stepTarget
                    }
                    maximumValue: stableScale
                    Behavior on maximumValue { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
                    seriesData: [{
                        label: "Totale",
                        color: ResourceUsage.cpuUsage > 0.8 ? "#ff5555" : "#33c481",
                        valueText: (ResourceUsage.cpuUsage * 100).toFixed(1) + "%",
                        data: ResourceUsage.cpuUsageHistory
                    }]
                }

                ResourceGraph {
                    title: "Memoria"
                    readonly property real currentUsage: ResourceUsage.memoryUsedPercentage
                    property real stableScale: 0.20
                    onCurrentUsageChanged: {
                        let rawTarget = currentUsage * 1.1
                        let stepTarget = Math.ceil(rawTarget / 0.20) * 0.20
                        if (stepTarget < 0.20) stepTarget = 0.20
                        if (stepTarget > 1.0) stepTarget = 1.0
                        if (stepTarget > stableScale) stableScale = stepTarget
                        else if (stepTarget < stableScale && currentUsage < (stableScale - 0.15)) stableScale = stepTarget
                    }
                    maximumValue: stableScale
                    Behavior on maximumValue { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
                    seriesData: [{
                        label: "RAM Usata",
                        color: "#a371f7",
                        valueText: ResourceUsage.kbToGbString(ResourceUsage.memoryUsed),
                        data: ResourceUsage.memoryUsageHistory
                    }]
                }

                ResourceGraph {
                    title: "Temperatura CPU"
                    // Logica scala: Base 90°C. Se sale oltre, si adatta.
                    readonly property real currentTemp: ResourceUsage.cpuTemperature
                    property real stableScale: 90
                    
                    onCurrentTempChanged: {
                         // Se la temp supera la scala attuale, aumenta
                        if (currentTemp > stableScale) {
                            stableScale = Math.ceil(currentTemp / 10) * 10
                        } 
                        // Se scende molto sotto (es. scala 100 ma temp 70), riduci a 90 (minimo)
                        else if (stableScale > 90 && currentTemp < stableScale - 15) {
                            let newScale = Math.ceil((currentTemp + 5) / 10) * 10
                            stableScale = Math.max(90, newScale)
                        }
                    }

                    maximumValue: stableScale
                    Behavior on maximumValue { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }

                    seriesData: [{
                        label: "Package",
                        color: "#ff6b6b", // Rosso pastello
                        valueText: ResourceUsage.cpuTemperature.toFixed(0) + "°C",
                        data: ResourceUsage.tempHistory 
                    }]
                }
                
                ResourceGraph {
                    title: "Ventole (RPM)"
                    readonly property int currentPeak: Math.max(ResourceUsage.fan1RPM, ResourceUsage.fan2RPM)
                    property int stableScale: 4000
                    onCurrentPeakChanged: {
                        let rawTarget = currentPeak * 1.2
                        let stepTarget = Math.ceil(rawTarget / 1000) * 1000
                        if (stepTarget < 4000) stepTarget = 4000
                        if (stepTarget > stableScale) stableScale = stepTarget
                        else if (stepTarget < stableScale * 0.75) stableScale = stepTarget
                    }
                    maximumValue: stableScale
                    Behavior on maximumValue { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
                    seriesData: [
                        { label: "Ventola 1", color: "#f7b171", valueText: ResourceUsage.fan1RPM + "", data: ResourceUsage.fan1History },
                        { label: "Ventola 2", color: "#4fbbfd", valueText: ResourceUsage.fan2RPM + "", data: ResourceUsage.fan2History }
                    ]
                }

                // Spazio extra per lo scroll
                Item { height: 10 }
            }
        }
    }
}