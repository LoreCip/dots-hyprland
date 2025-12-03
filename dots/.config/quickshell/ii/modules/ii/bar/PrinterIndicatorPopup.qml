import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    required property int jobCount 

    StyledPopupValueRow {
        icon: "memory"
        label: "Lavori in coda"
        value: root.jobCount
    }
}
