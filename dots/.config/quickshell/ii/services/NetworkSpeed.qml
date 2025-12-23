pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Proprietà esposte (byte al secondo)
    property real downloadSpeed: 0
    property real uploadSpeed: 0
    property string activeInterface: "none"
    
    // Proprietà formattate per la UI
    readonly property string downloadSpeedStr: formatSpeed(downloadSpeed)
    readonly property string uploadSpeedStr: formatSpeed(uploadSpeed)

    // Variabili interne per il calcolo
    property var _lastRx: 0
    property var _lastTx: 0
    property var _lastTime: 0

    function formatSpeed(bytes) {
        if (bytes < 1024) return bytes.toFixed(0) + " B/s";
        let kb = bytes / 1024;
        if (kb < 1024) return kb.toFixed(1) + " KB/s";
        let mb = kb / 1024;
        return mb.toFixed(1) + " MB/s";
    }

    function refresh() {
        if (netProc.running) return;
        netProc.running = true;
    }

    Timer {
        id: refreshTimer
        interval: 1000 // Aggiornamento ogni secondo per precisione istantanea
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: netProc
        // Usiamo 'sh' per compatibilità e 'ip route' per trovare l'interfaccia di default.
        // L'output sarà: nome_interfaccia rx_bytes tx_bytes
        command: [
            "sh", "-c", 
            "I=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \\K\\S+'); [ -n \"$I\" ] && printf \"%s %s\" \"$I\" \"$(cat /sys/class/net/$I/statistics/rx_bytes) $(cat /sys/class/net/$I/statistics/tx_bytes)\""
        ]
        
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = text.trim();
                if (!raw) return;

                let parts = raw.split(/\s+/);
                if (parts.length < 3) return;

                let iface = parts[0];
                let rx = parseInt(parts[1]);
                let tx = parseInt(parts[2]);
                let now = Date.now();

                if (root.activeInterface === iface && root._lastTime > 0) {
                    let timeDelta = (now - root._lastTime) / 1000;
                    if (timeDelta > 0) {
                        root.downloadSpeed = (rx - root._lastRx) / timeDelta;
                        root.uploadSpeed = (tx - root._lastTx) / timeDelta;
                    }
                } else {
                    root.downloadSpeed = 0;
                    root.uploadSpeed = 0;
                    root.activeInterface = iface;
                }

                root._lastRx = rx;
                root._lastTx = tx;
                root._lastTime = now;
            }
        }
    }
}