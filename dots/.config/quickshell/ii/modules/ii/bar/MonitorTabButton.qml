import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    
    // API
    property string label: ""
    property string icon: ""
    property bool isActive: false
    signal clicked()

    Layout.fillWidth: true
    height: 36
    radius: Appearance.rounding.full // Pill shape
    
    // Styling
    color: isActive ? Appearance.colors.colSecondaryContainer : "transparent"
    border.color: isActive ? Appearance.colors.colOutline : Appearance.colors.colOutlineVariant
    border.width: 1

    // Animazioni
    scale: tapHandler.pressed ? 0.96 : 1.0
    Behavior on scale { 
        NumberAnimation { 
            duration: Appearance.animation.clickBounce.duration 
            easing.type: Appearance.animation.clickBounce.type
            easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
        } 
    }
    Behavior on color { ColorAnimation { duration: 150 } }

    RowLayout {
        anchors.centerIn: parent
        spacing: 8 
        
        MaterialSymbol {
            text: root.icon
            fill: root.isActive ? 1 : 0
            iconSize: Appearance.font.pixelSize.large
            color: root.isActive ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
        }
        
        Text {
            text: root.label
            color: root.isActive ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
            font.bold: root.isActive
            font.pixelSize: Appearance.font.pixelSize.normal
            font.family: Appearance.font.family.main
        }
    }

    TapHandler {
        id: tapHandler
        onTapped: root.clicked()
    }
}