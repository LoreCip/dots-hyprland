pragma Singleton
pragma ComponentBehavior: Bound

import QtQml.Models
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

/**
 * A service that provides easy access to the active Mpris player.
 * Modified to aggressively filter out empty players (like browsers with no media).
 */
Singleton {
	id: root;
	property list<MprisPlayer> players: Mpris.players.values.filter(player => isRealPlayer(player));
	property MprisPlayer trackedPlayer: null;
	property MprisPlayer activePlayer: trackedPlayer ?? Mpris.players.values[0] ?? null;
	signal trackChanged(reverse: bool);

	property bool __reverse: false;

	property var activeTrack;

	readonly property bool hasActivePlasmaIntegration: Mpris.players.values.some(
		p => p.dbusName?.startsWith('org.mpris.MediaPlayer2.plasma-browser-integration')
	)
	function isRealPlayer(player) {
        if (!Config.options.media.filterDuplicatePlayers) {
            return true;
        }
        return (
            // Remove native browser buses only if plasma-browser-integration is actually active on D-Bus
            !(hasActivePlasmaIntegration && player.dbusName.startsWith('org.mpris.MediaPlayer2.firefox')) && !(hasActivePlasmaIntegration && player.dbusName.startsWith('org.mpris.MediaPlayer2.chromium')) &&
            // playerctld just copies other buses and we don't need duplicates
            !player.dbusName?.startsWith('org.mpris.MediaPlayer2.playerctld') &&
            !(player.dbusName?.endsWith('.mpd') && !player.dbusName.endsWith('MediaPlayer2.mpd'))
        );
    }

    Instantiator {
        model: Mpris.players;

        Connections {
            required property MprisPlayer modelData;
            target: modelData;

            // --- QUANDO UN PLAYER VIENE TROVATO ---
            Component.onCompleted: {
                // Se non stiamo seguendo nessuno, o se quello nuovo sta suonando ED ha dati validi, prendiamolo
                if (root.trackedPlayer == null || (modelData.playbackState === MprisPlaybackState.Playing && modelData.trackTitle !== "")) {
                    root.trackedPlayer = modelData;
                }
            }

            // --- QUANDO UN PLAYER VIENE CHIUSO ---
            Component.onDestruction: {
                // Se muore il player attivo, cerchiamo subito un sostituto valido
                if (root.trackedPlayer === modelData) {
                    root.trackedPlayer = root.findBestFallback();
                }
            }

            // --- QUANDO LO STATO CAMBIA (Play/Pause) ---
            function onPlaybackStateChanged() {
                // Se questo player inizia a suonare ED ha un titolo, diventa il capo
                if (modelData.playbackState === MprisPlaybackState.Playing && modelData.trackTitle !== "") {
                    root.trackedPlayer = modelData;
                } 
                // Se il player attuale va in pausa, controlliamo se c'è qualcun altro che sta suonando
                else if (root.trackedPlayer === modelData && modelData.playbackState !== MprisPlaybackState.Playing) {
                    var betterCandidate = root.findBestFallback();
                    if (betterCandidate && betterCandidate.playbackState === MprisPlaybackState.Playing) {
                        root.trackedPlayer = betterCandidate;
                    }
                }
            }
            
            // --- AGGIUNTA: QUANDO CAMBIANO I METADATI ---
            // Fondamentale per i browser: a volte partono vuoti e poi caricano il titolo.
            function onMetadataChanged() {
                // Se questo player non era considerato (perché vuoto) ma ora ha un titolo e suona, prendilo!
                if (root.trackedPlayer !== modelData && modelData.playbackState === MprisPlaybackState.Playing && modelData.trackTitle !== "") {
                    root.trackedPlayer = modelData;
                }
            }
        }
    }

    Connections {
        target: activePlayer

        function onPostTrackChanged() {
            root.updateTrack();
        }

        function onTrackArtUrlChanged() {
            if (root.activePlayer.uniqueId == root.activeTrack.uniqueId && root.activePlayer.trackArtUrl != root.activeTrack.artUrl) {
                const r = root.__reverse;
                root.updateTrack();
                root.__reverse = r;
            }
        }
    }

    onActivePlayerChanged: this.updateTrack();

    function updateTrack() {
        this.activeTrack = {
            uniqueId: this.activePlayer?.uniqueId ?? 0,
            artUrl: this.activePlayer?.trackArtUrl ?? "",
            title: this.activePlayer?.trackTitle || Translation.tr("Unknown Title"),
            artist: this.activePlayer?.trackArtist || Translation.tr("Unknown Artist"),
            album: this.activePlayer?.trackAlbum || Translation.tr("Unknown Album"),
        };

        this.trackChanged(__reverse);
        this.__reverse = false;
    }

    property bool isPlaying: this.activePlayer && this.activePlayer.playbackState === MprisPlaybackState.Playing;
    property bool canTogglePlaying: this.activePlayer?.canTogglePlaying ?? false;
    function togglePlaying() {
        if (this.canTogglePlaying) this.activePlayer.togglePlaying();
    }

    property bool canGoPrevious: this.activePlayer?.canGoPrevious ?? false;
    function previous() {
        if (this.canGoPrevious) {
            this.__reverse = true;
            this.activePlayer.previous();
        }
    }

    property bool canGoNext: this.activePlayer?.canGoNext ?? false;
    function next() {
        if (this.canGoNext) {
            this.__reverse = false;
            this.activePlayer.next();
        }
    }

    property bool canChangeVolume: this.activePlayer && this.activePlayer.volumeSupported && this.activePlayer.canControl;

    property bool loopSupported: this.activePlayer && this.activePlayer.loopSupported && this.activePlayer.canControl;
    property var loopState: this.activePlayer?.loopState ?? MprisLoopState.None;
    function setLoopState(loopState: var) {
        if (this.loopSupported) {
            this.activePlayer.loopState = loopState;
        }
    }

    property bool shuffleSupported: this.activePlayer && this.activePlayer.shuffleSupported && this.activePlayer.canControl;
    property bool hasShuffle: this.activePlayer?.shuffle ?? false;
    function setShuffle(shuffle: bool) {
        if (this.shuffleSupported) {
            this.activePlayer.shuffle = shuffle;
        }
    }

    function setActivePlayer(player: MprisPlayer) {
        // Anche qui, forziamo il controllo
        const targetPlayer = player ?? findBestFallback();
        // console.log(`[Mpris] Active player ${targetPlayer} << ${activePlayer}`)

        if (targetPlayer && this.activePlayer) {
            this.__reverse = Mpris.players.indexOf(targetPlayer) < Mpris.players.indexOf(this.activePlayer);
        } else {
            this.__reverse = false;
        }

        this.trackedPlayer = targetPlayer;
    }

    IpcHandler {
        target: "mpris"

        function pauseAll(): void {
            for (const player of Mpris.players.values) {
                if (player.canPause) player.pause();
            }
        }

        function playPause(): void { root.togglePlaying(); }
        function previous(): void { root.previous(); }
        function next(): void { root.next(); }
    }
}