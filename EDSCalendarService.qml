import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

QtObject {
    id: root

    property var events: ([])
    property bool loading: false
    property bool available: false
    property string lastError: ""
    property var calendars: ([])
    readonly property string scriptsDir: Qt.resolvedUrl("./scripts").toString().replace("file://", "")
    readonly property string checkCalendarAvailableScript: scriptsDir + "/check-calendar.py"
    readonly property string listCalendarsScript: scriptsDir + "/list-calendars.py"
    readonly property string calendarEventsScript: scriptsDir + "/calendar-events.py"
    // --- Persistent cache ---
    property string cacheFile: (typeof Paths !== "undefined") ? (Paths.strip(Paths.cache) + "/weeklyCalendar/calendar.json") : ""
    property FileView cacheFileView

    cacheFileView: FileView {
        path: root.cacheFile
        onLoaded: {
            try {
                var data = JSON.parse(text);
                if (data.events)
                    root.events = data.events;

                if (data.calendars)
                    root.calendars = data.calendars;

            } catch (e) {
                console.error("[WeeklyCalendar] Failed to parse cache:", e);
            }
        }
    }

    property Process availabilityCheckProcess

    availabilityCheckProcess: Process {
        running: false
        command: ["python3", root.checkCalendarAvailableScript]

        stdout: StdioCollector {
            onStreamFinished: {
                var result = text.trim();
                if (result === "available") {
                    root.available = true;
                    loadCalendars();
                } else {
                    root.available = false;
                    root.lastError = "Evolution Data Server libraries not installed";
                }
            }
        }

    }

    property Process listCalendarsProcess

    listCalendarsProcess: Process {
        running: false
        command: ["python3", root.listCalendarsScript]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var result = JSON.parse(text.trim());
                    root.calendars = result;
                    root.saveCache();
                    if (result.length > 0)
                        loadEvents();

                } catch (e) {
                    root.lastError = "Failed to parse calendar list";
                }
            }
        }

    }

    property Process loadEventsProcess

    loadEventsProcess: Process {
        property int startTime: 0
        property int endTime: 0

        running: false
        command: ["python3", root.calendarEventsScript, startTime.toString(), endTime.toString()]

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    var result = JSON.parse(text.trim());
                    root.events = result;
                    root.saveCache();
                } catch (e) {
                    root.lastError = "Failed to parse events";
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                if (text.trim())
                    root.lastError = text.trim();

            }
        }

    }

    function saveCache() {
        if (!cacheFile)
            return ;

        var data = {
            "events": root.events,
            "calendars": root.calendars,
            "lastUpdate": new Date().toISOString()
        };
        cacheFileView.text = JSON.stringify(data);
    }

    function init() {
        availabilityCheckProcess.running = true;
    }

    function loadCalendars() {
        listCalendarsProcess.running = true;
    }

    function loadEvents(daysAhead, daysBehind) {
        var ahead = (daysAhead !== undefined ? daysAhead : 31);
        var behind = (daysBehind !== undefined ? daysBehind : 14);
        root.loading = true;
        root.lastError = "";
        var now = new Date();
        var startDate = new Date(now.getTime() - (behind * 24 * 60 * 60 * 1000));
        var endDate = new Date(now.getTime() + (ahead * 24 * 60 * 60 * 1000));
        loadEventsProcess.startTime = Math.floor(startDate.getTime() / 1000);
        loadEventsProcess.endTime = Math.floor(endDate.getTime() / 1000);
        loadEventsProcess.running = true;
    }

}
