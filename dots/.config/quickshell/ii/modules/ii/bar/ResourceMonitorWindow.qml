import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes

import qs.modules.common
import qs.services

Window {
    id: rootWindow
    width: 400
    height: 700
    visible: false 
    title: "Monitor Risorse"
    color: "#1e1e1e"

    component ResourceGraph: Item {
        id: graphRoot
        property string title: ""
        property var seriesData: [] 
        property real maximumValue: 1.0

        Layout.fillWidth: true
        Layout.preferredHeight: 200

        onSeriesDataChanged: graphCanvas.requestPaint()

        Rectangle {
            anchors.fill: parent
            color: "#2d2d2d"
            radius: 4
            border.color: "#3d3d3d"
            border.width: 1

            // --- HEADER ---
            RowLayout {
                anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                anchors.margins: 10
                height: 20; z: 10; spacing: 15
                
                Text {
                    text: graphRoot.title
                    color: "white"; font.bold: true; font.pixelSize: 14
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
                anchors.top: parent.top; anchors.bottom: parent.bottom
                anchors.left: parent.left; anchors.right: parent.right
                anchors.topMargin: 45; anchors.bottomMargin: 25
                anchors.leftMargin: 10; anchors.rightMargin: 10
                
                // 1. CANVAS (IL GRAFICO) - Ora è il primo, quindi sta SOTTO
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
                        var w = width; var h = height;
                        
                        ctx.reset();
                        ctx.clearRect(0, 0, w, h);
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
                            ctx.beginPath();
                            var val0 = data[0] * scaleFactor;
                            val0 = (val0 > h) ? h : (val0 < 0 ? 0 : val0);
                            ctx.moveTo(0, h);
                            
                            var i, x, val, y;
                            for (i = 0; i < count; i++) {
                                val = data[i] * scaleFactor;
                                if (val > h) val = h; else if (val < 0) val = 0;
                                x = ~~(i * stepX); y = ~~(h - val);
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
                            ctx.moveTo(0, ~~(h - val0));
                            for (i = 1; i < count; i++) {
                                val = data[i] * scaleFactor;
                                if (val > h) val = h; else if (val < 0) val = 0;
                                x = ~~(i * stepX); y = ~~(h - val);
                                ctx.lineTo(x, y);
                            }
                            ctx.strokeStyle = color; 
                            ctx.stroke();
                        }
                    }
                }

                Repeater {
                    model: 5 
                    Item {
                        width: parent.width; height: 1
                        y: Math.floor(index * (plotArea.height / 4))
                        
                        Rectangle { 
                            width: parent.width; height: 1; 
                            color: "#3d3d3d"; opacity: 0.6 
                        }
                        
                        Text {
                            anchors.bottom: parent.top; anchors.left: parent.left; anchors.bottomMargin: 2
                            color: "#999"
                            font.pixelSize: 10 
                            style: Text.Outline; styleColor: "#1e1e1e"
                            
                            text: {
                                let step = graphRoot.maximumValue / 4
                                let val = graphRoot.maximumValue - (index * step)
                                return graphRoot.maximumValue <= 1.0 ? (val * 100).toFixed(0) + "%" : val.toFixed(0)
                            }
                        }
                    }
                }

                // 3. INTERATTIVITÀ (Sempre sopra tutto)
                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true 
                    
                    property int hoveredIndex: -1
                    property bool isHovering: containsMouse

                    onPositionChanged: (mouse) => {
                        if (graphRoot.seriesData.length > 0 && graphRoot.seriesData[0].data && graphRoot.seriesData[0].data.length > 0) {
                            let count = graphRoot.seriesData[0].data.length
                            let stepX = width / (count - 1)
                            let idx = Math.round(mouse.x / stepX)
                            hoveredIndex = Math.max(0, Math.min(idx, count - 1))
                        }
                    }
                    onExited: hoveredIndex = -1

                    // Cursore
                    Rectangle {
                        visible: hoverArea.isHovering && hoverArea.hoveredIndex >= 0
                        width: 1; height: parent.height
                        color: "white"; opacity: 0.5
                        x: {
                            if (graphRoot.seriesData.length === 0 || !graphRoot.seriesData[0].data) return 0
                            let count = graphRoot.seriesData[0].data.length
                            return hoverArea.hoveredIndex * (parent.width / (count - 1))
                        }
                    }

                    // Tooltip
                    Rectangle {
                        id: tooltipBox
                        visible: hoverArea.isHovering && hoverArea.hoveredIndex >= 0
                        width: tooltipLayout.implicitWidth + 20
                        height: tooltipLayout.implicitHeight + 16
                        color: "#252525"; border.color: "#555"; radius: 4
                        y: 10 
                        x: {
                            let targetX = (cursorLineX - width / 2)
                            let count = (graphRoot.seriesData[0] && graphRoot.seriesData[0].data) ? graphRoot.seriesData[0].data.length : 1
                            let cursorLineX = hoverArea.hoveredIndex * (parent.width / (count - 1))
                            if (targetX < 0) targetX = 0
                            if (targetX + width > parent.width) targetX = parent.width - width
                            return targetX
                        }
                        layer.enabled: true
                        
                        ColumnLayout {
                            id: tooltipLayout
                            anchors.centerIn: parent
                            spacing: 4
                            Text {
                                text: "-" + (60 - hoverArea.hoveredIndex) + "s"
                                color: "#888"; font.pixelSize: 10
                                Layout.alignment: Qt.AlignHCenter
                                visible: hoverArea.hoveredIndex >= 0
                            }
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
                                                return graphRoot.maximumValue <= 1.0 ? (val * 100).toFixed(1) + "%" : val.toFixed(0)
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

            // Footer Assi X
            RowLayout {
                anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 10; anchors.rightMargin: 10; anchors.bottomMargin: 5
                Text { text: "60s"; color: "#555"; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: "30s"; color: "#555"; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: "Now"; color: "#555"; font.pixelSize: 10 }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        ResourceGraph {
            title: "CPU"
            readonly property real currentUsage: ResourceUsage.cpuUsage
            property real stableScale: 0.20
            onCurrentUsageChanged: {
                let rawTarget = currentUsage * 1.1    
                let stepTarget = Math.ceil(rawTarget / 0.20) * 0.20
                if (stepTarget < 0.20) stepTarget = 0.20
                if (stepTarget > 1.0) stepTarget = 1.0
                if (stepTarget > stableScale) {
                    stableScale = stepTarget
                } 
                else if (stepTarget < stableScale) {
                    if (currentUsage < (stableScale - 0.15)) {
                        stableScale = stepTarget
                    }
                }
            }

            maximumValue: stableScale
            Behavior on maximumValue { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }

            seriesData: [
                {
                    label: "Totale",
                    color: ResourceUsage.cpuUsage > 0.8 ? "#ff5555" : "#33c481", // Diventa rosso se > 80% (assoluto)
                    valueText: (ResourceUsage.cpuUsage * 100).toFixed(1) + "%",
                    data: ResourceUsage.cpuUsageHistory
                }
            ]
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

                if (stepTarget > stableScale) {
                    stableScale = stepTarget
                } else if (stepTarget < stableScale) {
                    if (currentUsage < (stableScale - 0.15)) {
                        stableScale = stepTarget
                    }
                }
            }

            maximumValue: stableScale
            Behavior on maximumValue { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }

            seriesData: [
                {
                    label: "RAM Usata",
                    color: "#a371f7",
                    valueText: ResourceUsage.kbToGbString(ResourceUsage.memoryUsed),
                    data: ResourceUsage.memoryUsageHistory
                }
            ]
        }
        
        // 3. VENTOLE
        ResourceGraph {
            title: "Ventole (RPM)"
            readonly property int currentPeak: Math.max(ResourceUsage.fan1RPM, ResourceUsage.fan2RPM)
            property int stableScale: 4000

            onCurrentPeakChanged: {
                let rawTarget = currentPeak * 1.2
                let stepTarget = Math.ceil(rawTarget / 1000) * 1000
                if (stepTarget < 4000) stepTarget = 4000
                if (stepTarget > stableScale) {
                    stableScale = stepTarget
                } 
                else if (stepTarget < stableScale * 0.75) {
                    stableScale = stepTarget
                }
            }

            maximumValue: stableScale
            Behavior on maximumValue { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }

            seriesData: [
                {
                    label: "Ventola 1",
                    color: "#f7b171",
                    valueText: ResourceUsage.fan1RPM + "",
                    data: ResourceUsage.fan1History
                },
                {
                    label: "Ventola 2",
                    color: "#4fbbfd",
                    valueText: ResourceUsage.fan2RPM + "",
                    data: ResourceUsage.fan2History
                }
            ]
        }
    }
}