import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import qs.modules.common.functions

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Hyprland

Item {
    id: root
    
    // --- DATI PLAYER ---
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool isPlaying: activePlayer?.playbackState == MprisPlaybackState.Playing
    
    readonly property string trackTitle: activePlayer?.trackTitle || ""
    readonly property string trackArtist: activePlayer?.trackArtist || ""
    readonly property string artUrl: activePlayer?.trackArtUrl || ""

    readonly property string displayArtist: StringUtils.cleanMusicTitle(trackArtist)
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(trackTitle) || Translation.tr("No media")
    readonly property string fullLabel: `${cleanedTitle}${displayArtist ? ' • ' + displayArtist : ''}`

    Layout.fillHeight: true
    implicitWidth: Math.min(300, rowLayout.implicitWidth + rowLayout.spacing * 2)
    implicitHeight: Appearance.sizes.barHeight

    Timer {
        id: metadataDebounce
        interval: 100
        repeat: false
        onTriggered: executeCoverUpdate()
    }

    Connections {
        target: activePlayer
        function onTrackTitleChanged() { metadataDebounce.restart(); }
        function onTrackArtUrlChanged() { metadataDebounce.restart(); }
        function onTrackArtistChanged() { metadataDebounce.restart(); }
        function onPlaybackStateChanged() { metadataDebounce.restart(); }
    }
    
    onActivePlayerChanged: metadataDebounce.restart()

    // --- VARIABILI VISUALIZZAZIONE ---
    property string imageToShow: "" 
    property string storagePath: Directories.coverArt

    // --- FUNZIONE ESECUTIVA (Lanciata dal Timer) ---
    function executeCoverUpdate() {
        if (!root.artUrl) return;

        if (root.artUrl.startsWith("file://") || root.artUrl.startsWith("/")) {
            root.imageToShow = root.artUrl.startsWith("/") ? "file://" + root.artUrl : root.artUrl;
            return;
        }

        let fileName = Qt.md5(root.artUrl);
        let targetFile = root.storagePath + "/" + fileName;

        downloadProc.targetFile = targetFile;
        downloadProc.command = [
            "curl", "-sSL", 
            "--connect-timeout", "3", 
            "--max-time", "10",
            "--create-dirs",
            "-o", targetFile, 
            root.artUrl
        ];
        
        downloadProc.running = true; 
    }

    Process {
        id: downloadProc
        property string targetFile
        onExited: (code) => {
            if (code === 0) {
                root.imageToShow = "file://" + targetFile + "?t=" + Math.random();
            }
        }
    }

    // --- CAVA VISUALIZER ---
    property int level0: 0
    property int level1: 0
    property int level2: 0
    property string dataBuffer: ""

    Process {
        id: cavaProc
        running: root.isPlaying 
        command: ["bash", "-c", 
            "printf '[general]\nbars=3\nframerate=25\n[input]\nmethod=pulse\n[output]\nchannels=mono\nmethod=raw\nraw_target=/dev/stdout\ndata_format=ascii\nascii_max_range=20\n' > /tmp/qs_bar_cava.conf && stdbuf -oL cava -p /tmp/qs_bar_cava.conf"
        ]
        stdout: SplitParser {
            onRead: (data) => {
                root.dataBuffer += data;
                const lastIndex = root.dataBuffer.lastIndexOf(";");
                if (lastIndex !== -1) {
                    const validChunk = root.dataBuffer.substring(0, lastIndex);
                    root.dataBuffer = root.dataBuffer.substring(lastIndex + 1);
                    const parts = validChunk.split(";").filter(p => p.trim() !== "");
                    const len = parts.length;
                    if (len >= 3) {
                        root.level0 = parseInt(parts[len-3]) || 0;
                        root.level1 = parseInt(parts[len-2]) || 0;
                        root.level2 = parseInt(parts[len-1]) || 0;
                    }
                }
            }
        }
    }

    Timer { 
        running: root.isPlaying
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: activePlayer.positionChanged()
    }

    MouseArea {
        id: navMouseArea // ID aggiunto per riferimento
        anchors.fill: parent
        hoverEnabled: true // Fondamentale per rilevare il passaggio del mouse
        acceptedButtons: Qt.AllButtons
        onPressed: (event) => {
            if (event.button === Qt.MiddleButton) activePlayer.togglePlaying();
            else if (event.button === Qt.BackButton) activePlayer.previous();
            else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) activePlayer.next();
            else if (event.button === Qt.LeftButton) GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
        }
    }

    RowLayout {
        id: rowLayout
        spacing: 8
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        // A. MINIATURA
        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: parent.height - 8
            Layout.preferredWidth: parent.height - 8

            Rectangle {
                id: coverMask
                anchors.fill: parent
                radius: 6
                color: Appearance.colors.colSecondaryContainer
                antialiasing: true

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "music_note"
                    iconSize: 14
                    color: Appearance.colors.colOnSecondaryContainer
                    visible: !finalCover.visible
                }
            }

            Image {
                id: coverSource
                anchors.fill: parent
                source: root.imageToShow
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            OpacityMask {
                id: finalCover
                anchors.fill: parent
                source: coverSource
                maskSource: coverMask
                antialiasing: true
                visible: root.imageToShow !== "" && coverSource.status === Image.Ready && root.isPlaying
            }
        }

        // B. TESTO SCORREVOLE
        Item {
            id: marqueeContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Text {
                id: mediaLabel
                text: root.fullLabel
                color: Appearance.colors.colOnLayer1
                font: Appearance.font.use(Appearance.font.name, Appearance.font.pixelSize.normal, 500)
                anchors.verticalCenter: parent.verticalCenter
                
                function resetPosition() {
                    marqueeAnim.stop();

                    var containerW = marqueeContainer.width;
                    var textW = mediaLabel.width;
                    
                    if (containerW <= 0 || textW <= 0) return;

                    if (textW > containerW) {
                        mediaLabel.x = 0;
                        mediaLabel.elide = Text.ElideRight;
                    } else {
                        mediaLabel.x = (containerW - textW) / 2;
                        mediaLabel.elide = Text.ElideNone;
                    }
                }

                onTextChanged: resetPosition()
                onWidthChanged: { if (!marqueeAnim.running) resetPosition() }
                
                Connections {
                    target: navMouseArea
                    function onContainsMouseChanged() {
                        if (!navMouseArea.containsMouse) {
                            mediaLabel.resetPosition();
                        } else if (mediaLabel.width > marqueeContainer.width) {
                            mediaLabel.elide = Text.ElideNone;
                            marqueeAnim.restart();
                        }
                    }
                }
                
                Connections {
                    target: marqueeContainer
                    function onWidthChanged() { mediaLabel.resetPosition() }
                }

                Component.onCompleted: resetPosition()

                SequentialAnimation on x {
                    id: marqueeAnim
                    running: false 
                    loops: Animation.Infinite
                    
                    PauseAnimation { duration: 500 }
                    
                    NumberAnimation {
                        from: 0
                        to: marqueeContainer.width - mediaLabel.width
                        duration: (mediaLabel.width - marqueeContainer.width) * 40 
                        easing.type: Easing.Linear
                    }
                    
                    PauseAnimation { duration: 1000 }
                    NumberAnimation { to: 0; duration: 500; easing.type: Easing.InOutQuad }
                }
            }
        }

        // C. VISUALIZER
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: 3
            
            Repeater {
                model: 3
                Item {
                    width: 3
                    height: 18
                    
                    Rectangle {
                        width: 3
                        radius: 1
                        color: Appearance.colors.colPrimary
                        anchors.centerIn: parent 
                        
                        property int level: {
                            if (index === 0) return root.level0;
                            if (index === 1) return root.level1;
                            return root.level2;
                        }
                        
                        height: root.isPlaying ? Math.max(4, Math.min(parent.height, 4 + level)) : 4
                        Behavior on height {
                            NumberAnimation { duration: 50; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }
    }
}