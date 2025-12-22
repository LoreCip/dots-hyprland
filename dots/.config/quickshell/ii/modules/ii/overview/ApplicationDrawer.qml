import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Qt.labs.settings 1.0

Item {
    id: root

    // --- PROPRIETÀ ---
    property bool expanded: false
    property string searchText: ""
    property string sortMode: "name" 
    property bool showHiddenOnly: false
    property var hiddenApps: []
    property var recentUsage: ({})

    property real collapsedHeight: 400
    property real availableHeight: 0
    property real availableWidth: 0
    property real iconSize: 50
    property real spacing: 30

    property var contextMenuApp: null
    property bool contextMenuVisible: false
    property point contextMenuPosition: Qt.point(0, 0)
    property bool propertiesDialogVisible: false
    property var propertiesDialogApp: null

    // Dimensioni dinamiche
    implicitHeight: expanded ? (availableHeight > 0 ? availableHeight * 0.85 : 600) : collapsedHeight
    
    property int appColumns: {
        const targetWidth = availableWidth > 0 ? availableWidth : width;
        return Math.max(6, Math.floor((targetWidth - 60) / 90));
    }

    // --- PERSISTENZA ---
    Settings {
        id: appSettings
        category: "ApplicationDrawer"
        property var savedHiddenApps: []
        property var savedRecentUsage: ({})
    }

    Component.onCompleted: {
        root.hiddenApps = appSettings.savedHiddenApps || [];
        root.recentUsage = appSettings.savedRecentUsage || {};
        appGrid.currentIndex = -1;
    }

    onHiddenAppsChanged: appSettings.savedHiddenApps = root.hiddenApps
    onRecentUsageChanged: appSettings.savedRecentUsage = root.recentUsage

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (!GlobalStates.overviewOpen) {
                root.showHiddenOnly = false;
                root.searchText = "";
                appGrid.currentIndex = -1;
                root.focus = true;
            }
        }
    }

    // --- LOGICA ---
    function getFilteredApps() {
        const list = AppSearch.list;
        if (!list) return [];
        
        const searchKey = root.searchText.toLowerCase();
        
        let filtered = Array.from(list).filter(function(app) {
            const id = app.desktopFile || app.name;
            const isHidden = root.hiddenApps.indexOf(id) !== -1;
            const matchesSearch = searchKey === "" || 
                app.name.toLowerCase().indexOf(searchKey) !== -1 ||
                (app.description && app.description.toLowerCase().indexOf(searchKey) !== -1);
            
            return (root.showHiddenOnly ? isHidden : !isHidden) && matchesSearch;
        });

        filtered.sort(function(a, b) {
            if (root.sortMode === "recent") {
                const idA = a.desktopFile || a.name;
                const idB = b.desktopFile || b.name;
                const timeA = root.recentUsage[idA] || 0;
                const timeB = root.recentUsage[idB] || 0;
                if (timeB !== timeA) return timeB - timeA;
            }
            return a.name.localeCompare(b.name);
        });

        return filtered;
    }

    function trackLaunch(app) {
        const id = app.desktopFile || app.name;
        // Uso Object.assign per compatibilità (evita l'errore '...')
        let usage = Object.assign({}, root.recentUsage);
        usage[id] = Date.now();
        root.recentUsage = usage;
    }

    function copyAppPath(app) {
        if (!app) return;
        const exec = app.exec || "";
        const execName = exec.split(" ")[0] || "";
        pathFinderProcess.execName = execName;
        pathFinderProcess.running = true;
    }

    Process {
        id: pathFinderProcess
        property string execName: ""
        command: ["which", execName]
        onExited: function(code) {
            Quickshell.clipboardText = (code === 0 && stdout.length > 0) ? stdout.trim() : execName;
        }
    }

    // --- COMPONENTI INTERNI RINOMINATI ---
    component DrawerHeaderButton: RippleButton {
        id: hBtn
        property string iconName: ""
        property string tip: ""
        Layout.preferredWidth: 32; Layout.preferredHeight: 32; buttonRadius: Appearance.rounding.full
        colBackground: "transparent"; colBackgroundHover: Appearance.colors.colLayer2
        contentItem: MaterialSymbol {
            anchors.centerIn: parent; text: hBtn.iconName
            iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colSubtext
        }
        StyledToolTip { text: hBtn.tip }
    }

    component DrawerMenuAction: RippleButton {
        id: mAction
        property string iconName: ""; property string labelText: ""
        Layout.fillWidth: true; implicitHeight: 36; buttonRadius: Appearance.rounding.small
        colBackground: "transparent"; colBackgroundHover: Appearance.colors.colLayer2
        contentItem: RowLayout {
            spacing: 12; Item { Layout.preferredWidth: 4 }
            MaterialSymbol { text: mAction.iconName; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnLayer0 }
            StyledText { Layout.fillWidth: true; text: mAction.labelText; font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer0 }
        }
    }

    // --- LAYOUT ---
    StyledRectangularShadow { target: drawerBg }

    Rectangle {
        id: drawerBg
        anchors.fill: parent; radius: Appearance.rounding.large
        color: Appearance.colors.colLayer0; border.width: 1; border.color: Appearance.colors.colLayer0Border

        ColumnLayout {
            anchors.fill: parent; anchors.margins: root.expanded ? 20 : 15; spacing: 10

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                MaterialSymbol { text: "apps"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnLayer0 }
                StyledText {
                    text: root.expanded ? Translation.tr("All Applications") : Translation.tr("Applications")
                    font.pixelSize: Appearance.font.pixelSize.larger; font.weight: Font.Medium; color: Appearance.colors.colOnLayer0
                }
                Item { Layout.fillWidth: true }
                
                DrawerHeaderButton {
                    iconName: root.showHiddenOnly ? "visibility" : "visibility_off"
                    tip: root.showHiddenOnly ? "Mostra normali" : "Gestisci nascoste"
                    colBackground: root.showHiddenOnly ? Appearance.colors.colSecondaryContainer : "transparent"
                    onClicked: root.showHiddenOnly = !root.showHiddenOnly
                }

                DrawerHeaderButton {
                    iconName: root.expanded ? "expand_less" : "expand_more"
                    tip: root.expanded ? "Comprimi" : "Espandi"
                    onClicked: root.expanded = !root.expanded
                }
            }

            TextField {
                id: searchField
                Layout.fillWidth: true; visible: root.expanded; Layout.maximumHeight: root.expanded ? implicitHeight : 0; opacity: root.expanded ? 1 : 0
                placeholderText: Translation.tr("Search..."); color: Appearance.m3colors.m3onSurface
                background: Rectangle { radius: Appearance.rounding.small; color: Appearance.colors.colLayer1; border.color: searchField.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant }
                onTextChanged: root.searchText = text
                MaterialSymbol {
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: "close"; visible: searchField.text.length > 0
                    MouseArea { anchors.fill: parent; onClicked: searchField.text = "" }
                }
            }

            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                GridView {
                    id: appGrid; anchors.fill: parent
                    cellWidth: Math.max(80, (parent.width - (root.appColumns - 1) * root.spacing - 30) / root.appColumns)
                    cellHeight: cellWidth * 1.3; currentIndex: -1
                    model: ScriptModel { values: { root.searchText; root.hiddenApps; root.showHiddenOnly; root.sortMode; return root.getFilteredApps(); } }

                    delegate: RippleButton {
                        width: appGrid.cellWidth; height: appGrid.cellHeight; buttonRadius: Appearance.rounding.normal
                        colBackground: (hovered || focus) ? Appearance.colors.colSecondaryContainer : "transparent"
                        onClicked: { root.trackLaunch(modelData); GlobalStates.overviewOpen = false; modelData.execute(); focus = false }
                        altAction: function(event) {
                            const pos = mapToItem(root, event.x, event.y);
                            root.contextMenuPosition = Qt.point(pos.x, pos.y);
                            root.contextMenuApp = modelData;
                            root.contextMenuVisible = true;
                        }
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 8; spacing: 6
                            IconImage { 
                                Layout.alignment: Qt.AlignHCenter; implicitSize: root.iconSize
                                source: {
                                    const icon = modelData.icon;
                                    return (icon.indexOf("/") === 0 || icon.indexOf("file://") === 0) ? "file://" + icon.replace("file://", "") : Quickshell.iconPath(icon, "image-missing");
                                }
                            }
                            StyledText { Layout.fillWidth: true; text: modelData.name; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.WordWrap; font.pixelSize: Appearance.font.pixelSize.smaller }
                        }
                    }
                }
            }
        }
    }

    // --- MENU CONTESTUALE ---
    Loader {
        active: root.contextMenuVisible; anchors.fill: parent
        sourceComponent: Item {
            anchors.fill: parent
            MouseArea { anchors.fill: parent; onPressed: root.contextMenuVisible = false }
            Rectangle {
                id: ctxRect
                x: Math.min(root.contextMenuPosition.x, parent.width - width - 10)
                y: Math.min(root.contextMenuPosition.y, parent.height - height - 10)
                width: Math.max(160, ctxCol.implicitWidth + 16); height: ctxCol.implicitHeight + 16
                radius: Appearance.rounding.normal; color: Appearance.m3colors.m3surfaceContainerHigh; border.width: 1; border.color: Appearance.colors.colLayer0Border
                opacity: root.contextMenuVisible ? 1 : 0; scale: opacity ? 1 : 0.95
                Behavior on opacity { NumberAnimation { duration: 150 } }

                ColumnLayout {
                    id: ctxCol; anchors.fill: parent; anchors.margins: 8; spacing: 4
                    DrawerMenuAction { iconName: "content_copy"; labelText: "Copy path"; onClicked: { root.copyAppPath(root.contextMenuApp); root.contextMenuVisible = false } }
                    DrawerMenuAction {
                        property bool isH: root.contextMenuApp ? root.hiddenApps.indexOf(root.contextMenuApp.desktopFile || root.contextMenuApp.name) !== -1 : false
                        iconName: isH ? "visibility" : "visibility_off"
                        labelText: isH ? "Ripristina app" : "Nascondi app"
                        onClicked: {
                            const id = root.contextMenuApp.desktopFile || root.contextMenuApp.name;
                            let list = root.hiddenApps.slice();
                            const idx = list.indexOf(id);
                            if (idx > -1) list.splice(idx, 1); else list.push(id);
                            root.hiddenApps = list;
                            root.contextMenuVisible = false;
                        }
                    }
                    DrawerMenuAction { iconName: "info"; labelText: "Properties"; onClicked: { root.propertiesDialogApp = root.contextMenuApp; root.propertiesDialogVisible = true; root.contextMenuVisible = false } }
                }
            }
        }
    }
}