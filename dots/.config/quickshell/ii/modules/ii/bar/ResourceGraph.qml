import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    
    // API Pubblica
    property var seriesData: [] 
    property real maximumValue: 1.0
    
    // Layout
    Layout.fillWidth: true
    Layout.fillHeight: true

    // Trigger repaint
    Component.onCompleted: graphCanvas.requestPaint()
    onSeriesDataChanged: graphCanvas.requestPaint()

    // Sfondo Card
    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colLayer1
        radius: Appearance.rounding.small
        border.color: Appearance.colors.colOutlineVariant
        border.width: 1

        // Header Legenda
        RowLayout {
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: 10; height: 20; z: 10; spacing: 15
            
            Item { Layout.fillWidth: true } // Spacer

            RowLayout {
                spacing: 15
                Repeater {
                    model: root.seriesData
                    RowLayout {
                        spacing: 5
                        Rectangle { width: 8; height: 8; radius: 4; color: modelData.color }
                        Text { 
                            text: modelData.label
                            color: Appearance.colors.colOnSurfaceVariant
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.family: Appearance.font.family.main
                        }
                        Text { 
                            text: modelData.valueText
                            color: Appearance.colors.colOnSurface
                            font.bold: true
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.family: Appearance.font.family.monospace
                        }
                    }
                }
            }
        }

        // Area Plot
        Item {
            id: plotArea
            anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            anchors.topMargin: 35; anchors.bottomMargin: 25
            anchors.leftMargin: 10; anchors.rightMargin: 10
            
            // 1. CANVAS (Disegno SOTTO)
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

                    var seriesList = root.seriesData;
                    if (!seriesList || seriesList.length === 0) return;
                    var len = seriesList.length;

                    for (var s = 0; s < len; s++) {
                        var series = seriesList[s];
                        var data = series.data;
                        if (!data || data.length < 2) continue;
                        
                        var count = data.length;
                        var stepX = w / (count - 1);
                        var scaleFactor = h / root.maximumValue; 
                        var color = series.color || Appearance.colors.colPrimary;

                        // Fill Path
                        ctx.beginPath(); ctx.moveTo(0, h);
                        var i, x, val;
                        for (i = 0; i < count; i++) {
                            val = data[i] * scaleFactor; 
                            if (val > h) val = h; else if (val < 0) val = 0;
                            x = ~~(i * stepX); 
                            ctx.lineTo(x, ~~(h - val));
                        }
                        ctx.lineTo(w, h); ctx.closePath();
                        
                        ctx.save(); 
                        var grad = ctx.createLinearGradient(0, 0, 0, h);
                        grad.addColorStop(0, color); grad.addColorStop(1, "transparent"); 
                        ctx.globalAlpha = 0.20; ctx.fillStyle = grad; ctx.fill();
                        ctx.restore(); 

                        // Stroke Path
                        ctx.beginPath();
                        val = data[0] * scaleFactor; 
                        if (val > h) val = h; else if (val < 0) val = 0;
                        ctx.moveTo(0, ~~(h - val));
                        
                        for (i = 1; i < count; i++) {
                            val = data[i] * scaleFactor; 
                            if (val > h) val = h; else if (val < 0) val = 0;
                            ctx.lineTo(~~(i * stepX), ~~(h - val));
                        }
                        ctx.strokeStyle = color; ctx.stroke();
                    }
                }
            }

            // 2. GRIGLIA (Disegno SOPRA)
            Repeater {
                model: 5 
                Item {
                    width: parent.width; height: 1
                    y: Math.floor(index * (plotArea.height / 4))
                    
                    Rectangle { 
                        width: parent.width; height: 1; 
                        color: Appearance.colors.colOutlineVariant; opacity: 0.5 
                    }
                    
                    Text {
                        anchors.bottom: parent.top; anchors.left: parent.left; anchors.bottomMargin: 2
                        color: Appearance.colors.colOnSurfaceVariant
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.monospace
                        style: Text.Outline; styleColor: Appearance.colors.colLayer1
                        text: {
                            let step = root.maximumValue / 4
                            let val = root.maximumValue - (index * step)
                            return root.maximumValue <= 1.0 ? (val * 100).toFixed(0) + "%" : val.toFixed(0)
                        }
                    }
                }
            }

            // 3. INTERATTIVITÀ
            MouseArea {
                id: hoverArea; anchors.fill: parent; hoverEnabled: true 
                property int hoveredIndex: -1
                
                onPositionChanged: (mouse) => {
                    if (root.seriesData.length > 0 && root.seriesData[0].data && root.seriesData[0].data.length > 0) {
                        let count = root.seriesData[0].data.length
                        let stepX = width / (count - 1)
                        hoveredIndex = Math.max(0, Math.min(Math.round(mouse.x / stepX), count - 1))
                    }
                }
                onExited: hoveredIndex = -1

                // Cursore Verticale
                Rectangle {
                    visible: hoverArea.hoveredIndex >= 0
                    width: 1; height: parent.height; y: 0; 
                    color: Appearance.colors.colOnSurface; opacity: 0.5
                    x: {
                        if (root.seriesData.length === 0 || !root.seriesData[0].data) return 0
                        let count = root.seriesData[0].data.length
                        return hoverArea.hoveredIndex * (parent.width / (count - 1))
                    }
                }

                // Tooltip
                Rectangle {
                    id: tooltipBox
                    visible: hoverArea.hoveredIndex >= 0
                    y: 10
                    // Clamp X position
                    x: {
                        let targetX = (hoverArea.mouseX - width / 2)
                        if (targetX < 0) targetX = 0
                        if (targetX + width > parent.width) targetX = parent.width - width
                        return targetX
                    }
                    
                    width: tooltipCol.implicitWidth + 20; height: tooltipCol.implicitHeight + 16
                    color: Appearance.colors.colTooltip
                    border.color: Appearance.colors.colOutline
                    radius: Appearance.rounding.verysmall
                    layer.enabled: true
                    
                    ColumnLayout {
                        id: tooltipCol; anchors.centerIn: parent; spacing: 4
                        Repeater {
                            model: root.seriesData
                            RowLayout {
                                spacing: 8
                                Rectangle { width: 6; height: 6; radius: 3; color: modelData.color }
                                Text { 
                                    text: modelData.label; 
                                    color: Appearance.colors.colOnTooltip; opacity: 0.8
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.family: Appearance.font.family.main
                                }
                                Text {
                                    color: Appearance.colors.colOnTooltip
                                    font.bold: true
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.family: Appearance.font.family.monospace
                                    text: {
                                        let idx = hoverArea.hoveredIndex
                                        if (idx >= 0 && modelData.data && idx < modelData.data.length) {
                                            let val = modelData.data[idx]
                                            return root.maximumValue <= 1.0 ? (val * 100).toFixed(1) + "%" : val.toFixed(0)
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
        
        // Footer
        RowLayout {
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: 10; anchors.rightMargin: 10; anchors.bottomMargin: 5
            
            Text { text: "60s"; color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: Appearance.font.pixelSize.smallest; font.family: Appearance.font.family.main }
            Item { Layout.fillWidth: true }
            Text { text: "30s"; color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: Appearance.font.pixelSize.smallest; font.family: Appearance.font.family.main }
            Item { Layout.fillWidth: true }
            Text { text: "Now"; color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: Appearance.font.pixelSize.smallest; font.family: Appearance.font.family.main }
        }
    }
}