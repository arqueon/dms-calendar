import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    // --- Services ---
    EDSCalendarService {
        id: calendarService
    }

    // --- State & Logic ---
    property date currentDate: new Date()
    property ListModel eventsModel: ListModel {}
    property ListModel allDayEventsModel: ListModel {}
    property var overlappingEventsData: ({})
    property bool isLoading: (calendarService !== null ? calendarService.loading : false)
    property bool hasLoadedOnce: false
    property string syncStatus: ""

    property real dayColumnWidth: 120
    property real allDaySectionHeight: 0
    property real hourHeight: 50
    property var allDayEventsWithLayout: []

    property date weekStart: calculateWeekStart(currentDate, firstDayOfWeek)
    property date weekEnd: calculateWeekEnd(weekStart)
    property var weekDates: calculateWeekDates(weekStart)
    property string monthRangeText: formatMonthRangeText(weekDates)

    // Settings (DMS style)
    readonly property string weekStartSetting: (pluginData.weekStart !== undefined ? pluginData.weekStart : "1")
    readonly property string timeFormatSetting: (pluginData.timeFormat !== undefined ? (pluginData.timeFormat === true ? "12h" : "24h") : "24h")
    readonly property string lineColorTypeSetting: (pluginData.lineColorType !== undefined ? pluginData.lineColorType : "mOutline")
    readonly property real hourLineOpacitySetting: (pluginData.hourLineOpacity !== undefined ? pluginData.hourLineOpacity / 100 : 0.5)
    readonly property real dayLineOpacitySetting: (pluginData.dayLineOpacity !== undefined ? pluginData.dayLineOpacity / 100 : 0.9)

    readonly property int firstDayOfWeek: {
        if (weekStartSetting === "0") return 0;
        if (weekStartSetting === "1") return 1;
        if (weekStartSetting === "6") return 6;
        if (typeof SettingsData !== "undefined" && SettingsData.firstDayOfWeek !== -1)
            return SettingsData.firstDayOfWeek;
        return I18n.locale().firstDayOfWeek;
    }

    readonly property bool use12hourFormat: {
        if (timeFormatSetting === "12h") return true;
        if (timeFormatSetting === "24h") return false;
        if (typeof SettingsData !== "undefined")
            return !SettingsData.use24HourClock;
        return false;
    }

    // --- DMS Widget Properties ---
    ccWidgetIcon: "calendar_view_week"
    ccWidgetPrimaryText: "Weekly Calendar"
    ccWidgetSecondaryText: syncStatus
    ccWidgetIsActive: (calendarService !== null ? calendarService.available : false)

    ccDetailHeight: 600
    ccDetailContent: Component {
        WeeklyCalendarPanel {
            mainInstance: root
        }
    }

    // --- Bar Integration ---
    horizontalBarPill: Component {
        Item {
            implicitWidth: root.iconSize
            implicitHeight: root.iconSize
            DankIcon {
                anchors.centerIn: parent
                name: "calendar_view_week"
                size: root.iconSize
                color: Theme.primary
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.iconSize
            implicitHeight: root.iconSize
            DankIcon {
                anchors.centerIn: parent
                name: "calendar_view_week"
                size: root.iconSize
                color: Theme.primary
            }
        }
    }

    popoutContent: Component {
        WeeklyCalendarPanel {
            mainInstance: root
        }
    }
    popoutWidth: 900
    popoutHeight: 650

    // --- Initialization ---
    Component.onCompleted: {
        if (calendarService) calendarService.init();
    }

    Connections {
        target: calendarService
        function onEventsChanged() {
            updateEventsFromService();
        }
        function onAvailableChanged() {
            if (calendarService && calendarService.available) {
                initializePlugin();
            }
        }
    }

    function initializePlugin() {
        loadEvents();
    }

    function loadEvents() {
        if (!calendarService || !calendarService.available) return;
        
        syncStatus = "Loading...";
        calendarService.loadEvents(31, 14);
        hasLoadedOnce = true;
    }

    function updateEventsFromService() {
        if (!calendarService || !calendarService.available) {
            syncStatus = "Service unavailable";
        } else if (!calendarService.events || calendarService.events.length === 0) {
            syncStatus = "No events";
        } else {
            var stats = processCalendarEvents(calendarService.events);
            syncStatus = (stats.timedCount === 1 
                ? stats.timedCount + " event, " + stats.allDayCount + " all-day"
                : stats.timedCount + " events, " + stats.allDayCount + " all-day");
        }
    }

    // --- Helper Functions ---
    function calculateWeekStart(date, firstDay) {
        var d = new Date(date);
        var day = d.getDay();
        var diff = (day - firstDay + 7) % 7;
        d.setDate(d.getDate() - diff);
        d.setHours(0, 0, 0, 0);
        return d;
    }

    function calculateWeekDates(startDate) {
        var dates = [];
        var start = new Date(startDate);
        for (var i = 0; i < 7; i++) {
            var d = new Date(start);
            d.setDate(start.getDate() + i);
            dates.push(d);
        }
        return dates;
    }

    function calculateWeekEnd(startDate) {
        var end = new Date(startDate);
        end.setDate(end.getDate() + 7);
        end.setHours(0, 0, 0, 0);
        return end;
    }

    function formatMonthRangeText(dates) {
        if (!dates || dates.length === 0) return "";
        var start = dates[0], end = dates[6];
        var startMonth = I18n.locale().monthName(start.getMonth(), Locale.ShortFormat);
        var endMonth = I18n.locale().monthName(end.getMonth(), Locale.ShortFormat);
        
        if (start.getMonth() === end.getMonth() && start.getFullYear() === end.getFullYear()) {
            return startMonth + " " + start.getFullYear();
        } else if (start.getFullYear() === end.getFullYear()) {
            return startMonth + " – " + endMonth + " " + start.getFullYear();
        } else {
            return startMonth + " " + start.getFullYear() + " – " + endMonth + " " + end.getFullYear();
        }
    }

    function processCalendarEvents(events) {
        var timedCount = 0, allDayCount = 0;
        var newEvents = [], newAllDayEvents = [];
        var weekStartDate = new Date(weekStart), weekEndDate = new Date(weekEnd);
        
        for (var i = 0; i < events.length; i++) {
            var event = events[i];
            var start = new Date(event.start * 1000), end = new Date(event.end * 1000);
            
            if (start < weekEndDate && end > weekStartDate) {
                var duration = (event.end - event.start);
                var isAllDay = duration >= 86400 && start.getHours() === 0;

                var eventObj = {
                    id: event.uid || ("ev-" + i),
                    title: event.summary || "Untitled",
                    description: event.description || "",
                    location: event.location || "",
                    startTime: start,
                    endTime: end,
                    allDay: isAllDay,
                    calendar: event.calendar,
                    color: event.color || ""
                };

                if (isAllDay) {
                    allDayCount++;
                    newAllDayEvents.push(eventObj);
                } else {
                    timedCount++;
                    newEvents.push(eventObj);
                }
            }
        }
        
        eventsModel.clear();
        allDayEventsModel.clear();
        for (var j = 0; j < newEvents.length; j++) eventsModel.append(newEvents[j]);
        for (var k = 0; k < newAllDayEvents.length; k++) allDayEventsModel.append(newAllDayEvents[k]);
        
        calculateAllDayEventLayout();
        updateOverlappingEvents();
        
        return {timedCount: timedCount, allDayCount: allDayCount};
    }

    function calculateAllDayEventLayout() {
        var eventsWithLayout = [];
        for (var i = 0; i < allDayEventsModel.count; i++) {
            var event = allDayEventsModel.get(i);
            var startIdx = Math.max(0, getDayIndexForDate(event.startTime));
            var endIdx = Math.min(6, getDayIndexForDate(event.endTime));
            var span = Math.max(1, endIdx - startIdx + 1);
            
            eventsWithLayout.push({
                id: event.id, title: event.title,
                startDay: startIdx, spanDays: span, lane: 0
            });
        }
        allDayEventsWithLayout = eventsWithLayout;
        allDaySectionHeight = allDayEventsWithLayout.length > 0 ? 30 : 0;
    }

    function getDayIndexForDate(date) {
        if (!date) return -1;
        var dayDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        var ws = new Date(weekStart.getFullYear(), weekStart.getMonth(), weekStart.getDate());
        var diff = Math.round((dayDate.getTime() - ws.getTime()) / 86400000);
        return (diff >= 0 && diff < 7) ? diff : -1;
    }

    function updateOverlappingEvents() {
        var overlapData = {};
        for (var day = 0; day < 7; day++) {
            processDayEventsWithLanes(day, overlapData);
        }
        overlappingEventsData = overlapData;
    }

    function processDayEventsWithLanes(day, data) {
        var events = [];
        for (var i = 0; i < eventsModel.count; i++) {
            var e = eventsModel.get(i);
            if (getDayIndexForDate(e.startTime) === day) {
                events.push({index: i, start: e.startTime.getTime(), end: e.endTime.getTime()});
            }
        }
        if (events.length === 0) return;
        
        events.sort(function(a, b) {
            return a.start === b.start ? (b.end - b.start) - (a.end - a.start) : a.start - b.start;
        });

        var groups = [], current = [], endTime = -1;
        for (var j = 0; j < events.length; j++) {
            var e = events[j];
            if (e.start >= endTime) {
                if (current.length > 0) groups.push({events: current, endTime: endTime});
                current = [e]; endTime = e.end;
            } else {
                current.push(e);
                if (e.end > endTime) endTime = e.end;
            }
        }
        if (current.length > 0) groups.push({events: current, endTime: endTime});
        
        for (var k = 0; k < groups.length; k++) {
            assignLanesToGroup(groups[k].events, data);
        }
    }

    function assignLanesToGroup(group, data) {
        if (group.length === 0) return;
        var laneEnds = [];
        for (var i = 0; i < group.length; i++) {
            var e = group[i];
            var placed = false;
            for (var lane = 0; lane < laneEnds.length; lane++) {
                if (e.start >= laneEnds[lane]) {
                    laneEnds[lane] = e.end;
                    e.lane = lane;
                    placed = true;
                    break;
                }
            }
            if (!placed) { e.lane = laneEnds.length; laneEnds.push(e.end); }
        }
        
        var total = laneEnds.length;
        for (var j = 0; j < group.length; j++) {
            var eg = group[j];
            data[eg.index] = {
                lane: eg.lane,
                totalLanes: total
            };
        }
    }

    function navigateWeek(days) {
        var d = new Date(currentDate);
        d.setDate(d.getDate() + days);
        currentDate = d;
        loadEvents();
    }

    function goToToday() {
        currentDate = new Date();
        loadEvents();
    }
}
