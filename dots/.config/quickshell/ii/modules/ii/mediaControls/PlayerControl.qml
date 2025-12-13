pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item { // Player instance
    id: root
    required property MprisPlayer player
    
    // --- PROPRIETÀ ---
    property var artUrl: player?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    
    // Fallback sicuro per il colore
    property color artDominantColor: ColorUtils.mix(
        (colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary), 
        Appearance.colors.colPrimaryContainer, 0.8
    ) || Appearance.m3colors.m3secondaryContainer

    property bool downloaded: false
    property list<real> visualizerPoints: []
    property real maxVisualizerValue: 1000 
    property int visualizerSmoothing: 2 
    property real radius

    // Controlliamo se il file esiste davvero prima di provare a mostrarlo
    property string displayedArtFilePath: root.downloaded ? Qt.resolvedUrl(root.artFilePath) : ""

    // --- COMPONENTI INTERNI ---
    component TrackChangeButton: RippleButton {
        implicitWidth: 24
        implicitHeight: 24

        property var iconName
        colBackground: ColorUtils.transparentize(blendedColors.colSecondaryContainer, 1)
        colBackgroundHover: blendedColors.colSecondaryContainerHover
        colRipple: blendedColors.colSecondaryContainerActive

        contentItem: MaterialSymbol {
            iconSize: Appearance.font.pixelSize.huge
            fill: 1
            horizontalAlignment: Text.AlignHCenter
            color: blendedColors.colOnSecondaryContainer
            text: iconName

            // FIX LEAK: Usiamo un'animazione standard invece di creare oggetti
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    // --- LOGICA DI AGGIORNAMENTO ---
    
    // Timer per la barra di progresso (Mpris spesso non notifica la posizione in continuo)
    Timer { 
        running: root.player?.playbackState === MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    // Gestione download copertine
    onArtFilePathChanged: {
        if (!root.artUrl || root.artUrl.length === 0) {
            root.artDominantColor = Appearance.m3colors.m3secondaryContainer
            root.downloaded = false
            return;
        }

        // Se l'immagine è già cambiata mentre scaricavamo quella prima, fermiamo tutto
        if (coverArtDownloader.running) {
            coverArtDownloader.kill(); 
        }

        root.downloaded = false
        
        // Aggiorniamo i parametri del processo
        coverArtDownloader.targetFile = root.artUrl 
        coverArtDownloader.artFilePath = root.artFilePath
        
        // Avvia il download
        coverArtDownloader.running = true
    }

    Process { 
        id: coverArtDownloader
        property string targetFile: root.artUrl // Binding locale
        property string artFilePath: root.artFilePath // Binding locale
        
        // Usa -sSL per curl silenzioso e sicuro sui redirect
        command: [ "bash", "-c", `[ -f '${artFilePath}' ] || curl -sSL '${targetFile}' -o '${artFilePath}'` ]
        
        onExited: (exitCode, exitStatus) => {
            // Controllo di sicurezza: se il path è cambiato nel frattempo, non settare true
            if (root.artFilePath === artFilePath && exitCode === 0) {
                root.downloaded = true
            }
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0 
        rescaleSize: 1 // Ottimo per le performance
    }

    property QtObject blendedColors: AdaptedMaterialScheme {
        color: root.artDominantColor
    }

    // --- INTERFACCIA GRAFICA ---

    StyledRectangularShadow {
        target: background
    }
    
    Rectangle { // Background
        id: background
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
        color: ColorUtils.applyAlpha(blendedColors.colLayer0, 1)
        radius: root.radius

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        Image {
            id: blurredArt
            anchors.fill: parent
            source: root.displayedArtFilePath
            sourceSize.width: 100 // Ottimizzazione: carichiamo piccola per la sfocatura
            sourceSize.height: 100
            fillMode: Image.PreserveAspectCrop
            cache: false // Necessario per ricaricare se il file cambia
            asynchronous: true

            layer.enabled: true
            layer.effect: StyledBlurEffect {
                source: blurredArt
            }

            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(blendedColors.colLayer0, 0.3)
                radius: root.radius
            }
        }

        WaveVisualizer {
            id: visualizerCanvas
            anchors.fill: parent
            live: root.player?.isPlaying ?? false
            points: root.visualizerPoints
            maxVisualizerValue: root.maxVisualizerValue
            smoothing: root.visualizerSmoothing
            color: blendedColors.colPrimary
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 15

            Rectangle { // Art background
                id: artBackground
                Layout.fillHeight: true
                implicitWidth: height
                radius: Appearance.rounding.verysmall
                color: ColorUtils.transparentize(blendedColors.colLayer1, 0.5)
                
                // Clip per arrotondare l'immagine interna
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: artBackground.width
                        height: artBackground.height
                        radius: artBackground.radius
                    }
                }

                StyledImage { 
                    id: mediaArt
                    anchors.fill: parent
                    source: root.displayedArtFilePath
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    
                    // Ottimizzazione memoria: carica l'immagine alla dimensione esatta necessaria
                    sourceSize.width: artBackground.height 
                    sourceSize.height: artBackground.height
                }
            }

            ColumnLayout { // Info & controls
                Layout.fillHeight: true
                spacing: 2

                StyledText {
                    id: trackTitle
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: blendedColors.colOnLayer0
                    elide: Text.ElideRight
                    text: StringUtils.cleanMusicTitle(root.player?.trackTitle) || "Untitled"
                    animateChange: true
                    animationDistanceX: 6
                }
                StyledText {
                    id: trackArtist
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: blendedColors.colSubtext
                    elide: Text.ElideRight
                    text: StringUtils.cleanMusicTitle(root.player?.trackArtist)
                    animateChange: true
                    animationDistanceX: 6
                }
                
                Item { Layout.fillHeight: true } // Spacer

                Item {
                    Layout.fillWidth: true
                    implicitHeight: trackTime.implicitHeight + sliderRow.implicitHeight

                    StyledText {
                        id: trackTime
                        anchors.bottom: sliderRow.top
                        anchors.bottomMargin: 5
                        anchors.left: parent.left
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: blendedColors.colSubtext
                        text: `${StringUtils.friendlyTimeForSeconds(root.player?.position)} / ${StringUtils.friendlyTimeForSeconds(root.player?.length)}`
                    }

                    RowLayout {
                        id: sliderRow
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                        }
                        
                        TrackChangeButton {
                            iconName: "skip_previous"
                            downAction: () => root.player?.previous()
                        }

                        Item {
                            id: progressBarContainer
                            Layout.fillWidth: true
                            implicitHeight: Math.max(sliderLoader.implicitHeight, progressBarLoader.implicitHeight)

                            Loader {
                                id: sliderLoader
                                anchors.fill: parent
                                active: root.player?.canSeek ?? false
                                sourceComponent: StyledSlider { 
                                    configuration: StyledSlider.Configuration.Wavy
                                    highlightColor: blendedColors.colPrimary
                                    trackColor: blendedColors.colSecondaryContainer
                                    handleColor: blendedColors.colPrimary
                                    value: (root.player?.length > 0) ? (root.player.position / root.player.length) : 0
                                    onMoved: {
                                        if (root.player) root.player.position = value * root.player.length;
                                    }
                                }
                            }

                            Loader {
                                id: progressBarLoader
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                active: !(root.player?.canSeek ?? false)
                                sourceComponent: StyledProgressBar { 
                                    wavy: root.player?.isPlaying ?? false
                                    highlightColor: blendedColors.colPrimary
                                    trackColor: blendedColors.colSecondaryContainer
                                    value: (root.player?.length > 0) ? (root.player.position / root.player.length) : 0
                                }
                            }
                        }

                        TrackChangeButton {
                            iconName: "skip_next"
                            downAction: () => root.player?.next()
                        }
                    }

                    RippleButton {
                        id: playPauseButton
                        anchors.right: parent.right
                        anchors.bottom: sliderRow.top
                        anchors.bottomMargin: 5
                        property real size: 44
                        implicitWidth: size
                        implicitHeight: size
                        downAction: () => root.player?.togglePlaying();

                        buttonRadius: (root.player?.isPlaying ?? false) ? Appearance.rounding.normal : size / 2
                        colBackground: (root.player?.isPlaying ?? false) ? blendedColors.colPrimary : blendedColors.colSecondaryContainer
                        colBackgroundHover: (root.player?.isPlaying ?? false) ? blendedColors.colPrimaryHover : blendedColors.colSecondaryContainerHover
                        colRipple: (root.player?.isPlaying ?? false) ? blendedColors.colPrimaryActive : blendedColors.colSecondaryContainerActive

                        contentItem: MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.huge
                            fill: 1
                            horizontalAlignment: Text.AlignHCenter
                            color: (root.player?.isPlaying ?? false) ? blendedColors.colOnPrimary : blendedColors.colOnSecondaryContainer
                            text: (root.player?.isPlaying ?? false) ? "pause" : "play_arrow"

                            // FIX LEAK ANCHE QUI
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }
                }
            }
        }
    }
}