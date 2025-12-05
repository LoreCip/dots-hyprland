import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    // Helper function to format KB to GB
    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    Row {
        anchors.centerIn: parent
        spacing: 12

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "memory"
                label: "RAM"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: root.formatKB(ResourceUsage.memoryUsed)
                }
                StyledPopupValueRow {
                    icon: "check_circle"
                    label: Translation.tr("Free:")
                    value: root.formatKB(ResourceUsage.memoryFree)
                }
                StyledPopupValueRow {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: root.formatKB(ResourceUsage.memoryTotal)
                }
            }
        }

        Column {
            visible: ResourceUsage.swapTotal > 0 && ResourceUsage.swapUsed > 0
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "swap_horiz"
                label: "Swap"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: root.formatKB(ResourceUsage.swapUsed)
                }
                StyledPopupValueRow {
                    icon: "check_circle"
                    label: Translation.tr("Free:")
                    value: root.formatKB(ResourceUsage.swapFree)
                }
                StyledPopupValueRow {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: root.formatKB(ResourceUsage.swapTotal)
                }
            }
        }

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "planner_review"
                label: "CPU"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "bolt"
                    label: Translation.tr("Load:")
                    value: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
                }
                StyledPopupValueRow {
                        icon: "device_thermostat"
                        label: Translation.tr("Temp:")
                        value: `${Math.round(ResourceUsage.cpuTemperature || 0)}°C`
                }
                StyledPopupValueRow {
                        icon: "waves"
                        label: Translation.tr("Freq:")
                        value: `${Math.round(ResourceUsage.cpuAvgFrequency * 100 || 0) / 100} GHz`
                }
            }
        }

        // Column {
        //     anchors.top: parent.top
        //     spacing: 8
        // 
        //     StyledPopupHeaderRow {
        //         icon: "mode_fan"
        //         label: Translation.tr("Fans:")
        //     }
        //     Column {
        //         spacing: 4
        //         StyledPopupValueRow {
        //             icon: "toys_fan"
        //             label: Translation.tr("Fan %1:").arg(1)
        //             value: `${ResourceUsage.fan1RPM || 0} RPM`
        //         }
        //         StyledPopupValueRow {
        //                 icon: "toys_fan"
        //                 label: Translation.tr("Fan %1:").arg(2)
        //                 value: `${ResourceUsage.fan2RPM || 0} RPM`
        //         }
        //     }
        // }
    }
}