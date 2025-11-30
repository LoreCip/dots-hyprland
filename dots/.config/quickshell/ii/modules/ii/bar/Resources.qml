import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool alwaysShowAllResources: false
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    RowLayout {
        id: rowLayout

        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        Resource {
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            warningThreshold: Config.options.bar.resources.memoryWarningThreshold
        }

        Resource {
            iconName: "swap_horiz"
            percentage: ResourceUsage.swapUsedPercentage
            shown: (Config.options.bar.resources.alwaysShowSwap && percentage > 0) || 
                (MprisController.activePlayer?.trackTitle == null) ||
                root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.swapWarningThreshold
        }

        Resource {
            iconName: "planner_review"
            percentage: ResourceUsage.cpuUsage
            shown: Config.options.bar.resources.alwaysShowCpu || 
                !(MprisController.activePlayer?.trackTitle?.length > 0) ||
                root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.cpuWarningThreshold
        }

        // --- CPU TEMP (Nuova Aggiunta) ---
        Resource {
            // Icona "device_thermostat" o "thermostat" (Material Symbols)
            iconName: "device_thermostat" 
            
            // Assumiamo che ResourceUsage abbia una proprietà cpuTemperature.
            // Dividiamo per 100 perché Resource si aspetta un valore 0.0-1.0
            // Visualmente: 100°C = cerchio pieno.
            percentage: (ResourceUsage.cpuTemperature || 0) / 100 

            // Logica di visualizzazione: 
            // Modifica 'alwaysShowCpuTemp' con la tua effettiva configurazione
            shown: Config.options.bar.resources.alwaysShowCpuTemp || 
                   root.alwaysShowAllResources || 
                   (percentage * 100 > warningThreshold) // Mostra sempre se surriscalda

            Layout.leftMargin: shown ? 6 : 0
            
            // Imposta la soglia
            warningThreshold: Config.options.bar.resources.cpuTempWarningThreshold || 95
        }

    }

    ResourcesPopup {
        hoverTarget: root
    }
}
