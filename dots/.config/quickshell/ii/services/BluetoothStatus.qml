pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool available: Bluetooth.adapters.values.length > 0
    readonly property bool enabled: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property BluetoothDevice firstActiveDevice: Bluetooth.defaultAdapter?.devices.values.find(device => device.connected) ?? null
    readonly property int activeDeviceCount: Bluetooth.defaultAdapter?.devices.values.filter(device => device.connected).length ?? 0
    readonly property bool connected: Bluetooth.devices.values.some(d => d.connected)

    function sortFunction(a, b) {
        // Ones with meaningful names before MAC addresses
        const macRegex = /^([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}$/;
        const aIsMac = macRegex.test(a.name);
        const bIsMac = macRegex.test(b.name);
        if (aIsMac !== bIsMac)
            return aIsMac ? 1 : -1;

        // Alphabetical by name
        return a.name.localeCompare(b.name);
    }
    property list<var> connectedDevices: Bluetooth.devices.values.filter(d => d.connected).sort(sortFunction)
    property list<var> pairedButNotConnectedDevices: Bluetooth.devices.values.filter(d => d.paired && !d.connected).sort(sortFunction)
    property list<var> unpairedDevices: Bluetooth.devices.values.filter(d => !d.paired && !d.connected).sort(sortFunction)
    property list<var> friendlyDeviceList: [
        ...connectedDevices,
        ...pairedButNotConnectedDevices,
        ...unpairedDevices
    ]

    property var deviceList: []
    property bool popupVisible: false

    function refresh() {
        if (dumpProc.running) return;
        dumpProc.running = true;
    }

    onActiveDeviceCountChanged: {
        root.refresh()
        statusTimer.restart() // Riavvia il conteggio dei 5s per non sovrapporsi
    }
    Timer {
        interval: 5000
        running: root.connected && root.popupVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: dumpProc
        // Unica stringa per bash -c
        command: ["bash", "-c", "upower --dump"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                // Regex per separare i dispositivi
                let rawDevices = text.split(/Device:\s+/); 
                let parsedDevices = [];

                for (let i = 0; i < rawDevices.length; i++) {
                    let block = rawDevices[i];
                    if (block.trim().length === 0) continue;

                    let name = "Dispositivo";
                    let percent = -1;
                    let icon = "bluetooth"; // Default generico
                    let isSystemBattery = false;
                    let isDisplayDevice = false;
                    
                    // Flag per capire se abbiamo trovato il tipo specifico
                    let typeFound = false; 

                    let lines = block.split("\n");
                    for (let line of lines) {
                        line = line.trim();

                        // 1. Nome Modello
                        if (line.startsWith("model:")) {
                            name = line.split(":")[1].trim();
                        }

                        // 2. Percentuale
                        if (line.startsWith("percentage:")) {
                            let match = line.match(/(\d+)%/);
                            if (match) percent = parseInt(match[1]);
                        }

                        if (!typeFound) {
                            if (line === "mouse") {
                                icon = "mouse";
                                typeFound = true;
                            } else if (line === "keyboard") {
                                icon = "keyboard";
                                typeFound = true;
                            } else if (line === "headset" || line === "headphones") {
                                icon = "headphones";
                                typeFound = true;
                            } else if (line === "phone") {
                                icon = "smartphone";
                                typeFound = true;
                            } else if (line === "gaming_input" || line === "joystick") {
                                icon = "sports_esports"; // Gamepad
                                typeFound = true;
                            }
                        }

                        // 4. Check Batteria Interna
                        if (line.startsWith("native-path:")) {
                            if (/BAT\d+$/.test(line)) isSystemBattery = true;
                        }
                    }

                    // Fallback: Se UPower non ha scritto il tipo esplicito,
                    // guardiamo se il nome del modello contiene indizi.
                    if (!typeFound) {
                        let lowerName = name.toLowerCase();
                        if (lowerName.includes("mouse")) icon = "mouse";
                        else if (lowerName.includes("keyboard")) icon = "keyboard";
                        else if (lowerName.includes("bud") || lowerName.includes("head") || lowerName.includes("free")) icon = "headphones";
                    }

                    // Check DisplayDevice
                    if (block.includes("DisplayDevice")) isDisplayDevice = true;

                    // --- VALIDAZIONE ---
                    if (percent > -1 && !isSystemBattery && !isDisplayDevice) {
                        
                        // Logica Colori
                        let col = Appearance.m3colors.m3success; 
                        
                        if (percent <= 20) {
                            col = Appearance.colors.m3error;
                        } else if (percent <= 40) {
                            col = Appearance.m3colors.m3tertiary; 
                        }
                        
                        parsedDevices.push({
                            name: name,
                            percent: percent,
                            color: col,
                            icon: icon
                        });
                    }
                }
                
                root.deviceList = parsedDevices;
            }
        }
    }
}