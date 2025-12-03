import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    required property int jobCount 

    Row {
        anchors.centerIn: parent
        spacing: 12

        Column {
            anchors.top: parent.top
            spacing: 8
            StyledPopupValueRow {
                icon: none
                label: "Lavori in coda:"
                value: root.jobCount
            }
        }
    }
}
