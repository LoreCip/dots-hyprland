pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, CPU usage and fan rpm.
 */
Singleton {
    id: root
	property real memoryTotal: 1
	property real memoryFree: 0
	property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
	property real swapFree: 0
	property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property real cpuTemperature: 0 
    property real cpuAvgFrequency: 0
    property int fan1RPM: 0
    property int fan2RPM: 0
    
    property var previousCpuStats

    property string cpuTempPath: ""
    property string fan1RPMPath: ""
    property string fan2RPMPath: ""
    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function updateCpuAvgFrequency() {
        const text = fileFreq.text()
        const regex = /cpu MHz\s*:\s*([\d.]+)/g
        
        let match
        let totalFreq = 0
        let count = 0

        while ((match = regex.exec(text)) !== null) {
            totalFreq += parseFloat(match[1])
            count++
        }

        if (count > 0) {
            root.cpuAvgFrequency = (totalFreq / count) / 1000
        } else {
            root.cpuAvgFrequency = 0
        }
    }
    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
    }

	Timer {
		interval: 1000
        running: true 
        repeat: true
		onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()
            fileTemp.reload()
            fileFreq.reload()
            fileFan1RPM.reload()
            fileFan2RPM.reload()

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const textStat = fileStat.text()
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff = idle - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }

                previousCpuStats = { total, idle }
            }

            // Read CPU temperature
            const rawTemp = Number(fileTemp.text())
            if (!isNaN(rawTemp)) {
                cpuTemperature = rawTemp / 1000 // C
            }

            // Compute CPU avg frequency
            root.updateCpuAvgFrequency()

            // Read fans RPM
            const rawFan1 = Number(fileFan1RPM.text())
            if (!isNaN(rawFan1)) {
                fan1RPM = rawFan1
            }
            const rawFan2 = Number(fileFan2RPM.text())
            if (!isNaN(rawFan2)) {
                fan2RPM = rawFan2
            }

            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 1000
        }
	}

    // Find file with correct temp measurement
    Process {
        id: findTempPathProc
        command: ["bash", "-c", "grep -l 'x86_pkg_temp' /sys/class/thermal/thermal_zone*/type | head -n 1"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var typeFilePath = text.trim()
                if (typeFilePath !== "") {
                    root.cpuTempPath = typeFilePath.replace("type", "temp")                    
                    fileTemp.reload()
                }
            }
        }
    }

    // Find files with correct fan measurement
    Process {
        id: findRPMPathProc
        command: ["bash", "-c", "grep -Rl . /sys/class/hwmon/hwmon*/fan*_input"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var rpmFilePath = text.trim().split("\n")
                root.fan1RPMPath = rpmFilePath[0]
                root.fan2RPMPath = rpmFilePath[1]                  
                fileFan1RPM.reload()
                fileFan2RPM.reload()
            }
        }
    }

    FileView { id: fileFreq; path: "/proc/cpuinfo" }
    FileView { id: fileTemp; path: root.cpuTempPath }
    FileView { id: fileFan1RPM; path: root.fan1RPMPath }
    FileView { id: fileFan2RPM; path: root.fan2RPMPath }
	FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }

    Process {
        id: findCpuMaxFreqProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: false
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }
}
