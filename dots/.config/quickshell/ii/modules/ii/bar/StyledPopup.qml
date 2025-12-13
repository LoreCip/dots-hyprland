import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import QtQuick.Shapes 

LazyLoader {
    id: root

    property Item hoverTarget
    default property Item contentItem
    property real popupBackgroundMargin: 0

    active: hoverTarget && hoverTarget.containsMouse

    component: PanelWindow {
        id: popupWindow
        color: "transparent"

        anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

        implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin
        implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin

        mask: Region {
            item: popupBackground
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        
        margins {
            left: {
                var centeredX = root.QsWindow?.mapFromItem(
                    root.hoverTarget, 
                    (root.hoverTarget.width - popupBackground.implicitWidth) / 2, 0
                ).x;

                var screenWidth = popupWindow.screen.width;
                var popupWidth = popupBackground.implicitWidth;
                var rightMargin = 10; 

                if ((centeredX + popupWidth) > (screenWidth - rightMargin)) {
                    return screenWidth - popupWidth - rightMargin;
                }
                return centeredX;
            }
            // MODIFICA: Margine superiore fisso per "attaccarsi" alla barra
            top: {
                if (!Config.options.bar.vertical) return Appearance.sizes.barHeight;
                return root.QsWindow?.mapFromItem(
                    root.hoverTarget, 
                    (root.hoverTarget.height - popupBackground.implicitHeight) / 2, 0
                ).y;
            }
            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }
        
        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        // Ombra rettangolare (potrebbe richiedere aggiustamenti per le curve, ma ok per la base)
        StyledRectangularShadow {
            target: popupBackground
            offset.y: 4
        }

        Rectangle {
            id: popupBackground
            readonly property real margin: 10
            readonly property real curveRadius: 12 // Raggio della curva di connessione

            anchors {
                fill: parent
                leftMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin
                rightMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin
                topMargin: 0 
                bottomMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin
            }

            implicitWidth: root.contentItem.implicitWidth + margin * 2
            implicitHeight: root.contentItem.implicitHeight + margin * 2
            
            color: Appearance.colors.colLayer0 // Appearance.m3colors.m3surfaceContainer
            
            radius: Appearance.rounding.small
            Rectangle {
                width: parent.width
                height: parent.radius
                color: parent.color
                anchors.top: parent.top
            }

            border.width: 1
            border.color: Appearance.colors.colLayer0 // Appearance.colors.colLayer0Border
            
            transform: Translate {
                id: slideAnim
                y: -20 
            }
            opacity: 0

            states: State {
                name: "visible"
                when: popupWindow.visible
                PropertyChanges { target: slideAnim; y: 0 }
                PropertyChanges { target: popupBackground; opacity: 1 }
            }

            transitions: Transition {
                from: "*"
                to: "visible"
                ParallelAnimation {
                    NumberAnimation { target: slideAnim; property: "y"; duration: 250; easing.type: Easing.OutQuart }
                    NumberAnimation { target: popupBackground; property: "opacity"; duration: 200 }
                }
            }

            // Ala Sinistra
            Shape {
                width: popupBackground.curveRadius
                height: popupBackground.curveRadius
                anchors.right: parent.left
                anchors.top: parent.top
                
                layer.enabled: true
                layer.samples: 16

                ShapePath {
                    fillColor: popupBackground.color
                    strokeColor: "transparent"
                    startX: 0; startY: 0                    
                    PathArc { 
                        x: popupBackground.curveRadius; y: popupBackground.curveRadius
                        radiusX: popupBackground.curveRadius; radiusY: popupBackground.curveRadius
                        direction: PathArc.Clockwise 
                        useLargeArc: false
                    }
                    
                    PathLine { x: popupBackground.curveRadius; y: 0 }
                    PathLine { x: 0; y: 0 }
                }
            }

            // Ala Destra
            Shape {
                width: popupBackground.curveRadius
                height: popupBackground.curveRadius
                anchors.left: parent.right
                anchors.top: parent.top
                
                ShapePath {
                    fillColor: popupBackground.color
                    strokeColor: "transparent"
                    startX: 0; startY: 0
                    PathLine { x: 0; y: popupBackground.curveRadius }
                    PathArc { 
                        x: popupBackground.curveRadius; y: 0
                        radiusX: popupBackground.curveRadius; radiusY: popupBackground.curveRadius
                        direction: PathArc.Clockwise 
                    }
                }
            }

            // Contenuto effettivo
            Item {
                anchors.fill: parent
                anchors.margins: popupBackground.margin
                children: [root.contentItem]
            }
        }
    }
}