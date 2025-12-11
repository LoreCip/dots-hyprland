import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property bool isChargeLimited: Battery.isChargeLimited
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100

    implicitWidth: batteryProgress.implicitWidth * 1.2
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: !Config.options.bar.tooltips.clickToShow
    acceptedButtons: Qt.NoButton

    ClippedProgressBar {
        id: batteryProgress
        anchors.centerIn: parent
        value: percentage
        highlightColor: (isLow && !isCharging) ? Appearance.m3colors.m3error : Appearance.colors.colOnSecondaryContainer

        Item {
            anchors.centerIn: parent
            width: batteryProgress.valueBarWidth
            height: batteryProgress.valueBarHeight

            RowLayout {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: (parent.height - height) / 2
                }
                spacing: 0

                MaterialSymbol {
                    id: boltIcon
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: -2
                    Layout.rightMargin: -2
                    fill: 1
                    text: "bolt"
                    iconSize: Appearance.font.pixelSize.smaller
                    visible: isCharging && percentage < 1 
		            opacity: (isCharging && percentage < 1) ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 300; easing.type: Easing.InOutCubic }
                    }

                    onOpacityChanged: {
                        visible = opacity > 0
                    }
    	        }
                MaterialSymbol {
                    id: leafIcon
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: -2
                    Layout.rightMargin: -2
                    text: "eco"
                    iconSize: Appearance.font.pixelSize.smaller
                    visible: isChargeLimited && !isCharging
            	}
                StyledText {
                    id: batteryText	
                    Layout.alignment: Qt.AlignVCenter
                    font: batteryProgress.font
                    text: batteryProgress.text
                }
            }
        }
    }

    BatteryPopup {
        id: batteryPopup
        hoverTarget: root
    }
}
