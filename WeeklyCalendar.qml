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

    property string _calendarUri: "calendar://"

    Process {
        id: openCalendarProcess
        command: ["evolution", root._calendarUri]
    }

    function openEventInCalendar(calendarUid, eventUid) {
        if (calendarUid !== "" && eventUid !== "") {
            _calendarUri = "calendar://?source-uid=" + calendarUid + "&comp-uid=" + eventUid;
        } else {
            _calendarUri = "calendar://";
        }
        openCalendarProcess.running = false;
        openCalendarProcess.running = true;
    }

    // --- State & Logic ---
    property date currentDate: new Date()
    property string currentView: "week"  // "week" | "day" | "4days" | "agenda" | "month"
    property ListModel eventsModel: ListModel {}
    property ListModel allDayEventsModel: ListModel {}
    property ListModel agendaEvents: ListModel {}
    property var allRawEvents: []
    property var overlappingEventsData: ({})
    property bool isLoading: (calendarService !== null ? calendarService.loading : false)
    property bool hasLoadedOnce: false
    property string syncStatus: ""

    property real dayColumnWidth: 120
    property real allDaySectionHeight: 0
    property real hourHeight: 50
    property var allDayEventsWithLayout: []

    readonly property int viewColumnCount: currentView === "day" ? 1 : (currentView === "4days" ? 4 : 7)

    property date viewStart: calculateViewStart(currentDate, currentView, firstDayOfWeek)
    property date viewEnd: calculateViewEnd(viewStart, currentView)
    property var viewDates: calculateViewDates(viewStart, viewColumnCount)
    property var monthGridDates: currentView === "month" ? calculateMonthGridDates(currentDate, firstDayOfWeek) : []

    // Alias for panel compatibility
    readonly property date weekStart: viewStart

    property string monthRangeText: formatHeaderText(currentView, currentDate, viewDates)

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
    ccWidgetIcon: "calendar_month"
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
                name: "calendar_month"
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
                name: "calendar_month"
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
        // Wide range covers month navigation and agenda view
        calendarService.loadEvents(90, 60);
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

    // --- View Control ---
    function setView(view) {
        currentView = view;
        if (hasLoadedOnce && calendarService && calendarService.events && calendarService.events.length > 0) {
            processCalendarEvents(calendarService.events);
        }
    }

    // --- Helper Functions ---
    function calculateViewStart(date, view, firstDay) {
        var d;
        if (view === "day" || view === "4days" || view === "agenda") {
            d = new Date(date);
            d.setHours(0, 0, 0, 0);
        } else if (view === "month") {
            d = new Date(date.getFullYear(), date.getMonth(), 1);
            d.setHours(0, 0, 0, 0);
        } else {
            d = calculateWeekStart(date, firstDay);
        }
        return d;
    }

    function calculateWeekStart(date, firstDay) {
        var d = new Date(date);
        var day = d.getDay();
        var diff = (day - firstDay + 7) % 7;
        d.setDate(d.getDate() - diff);
        d.setHours(0, 0, 0, 0);
        return d;
    }

    function calculateViewEnd(startDate, view) {
        var end = new Date(startDate);
        if (view === "month") {
            end = new Date(startDate.getFullYear(), startDate.getMonth() + 1, 0);
        } else {
            var cols = view === "day" ? 1 : (view === "4days" ? 4 : 7);
            end.setDate(end.getDate() + cols);
        }
        end.setHours(23, 59, 59, 999);
        return end;
    }

    function calculateViewDates(startDate, count) {
        var dates = [];
        var start = new Date(startDate);
        for (var i = 0; i < count; i++) {
            var d = new Date(start);
            d.setDate(start.getDate() + i);
            dates.push(d);
        }
        return dates;
    }

    function calculateMonthGridDates(date, firstDay) {
        var firstOfMonth = new Date(date.getFullYear(), date.getMonth(), 1);
        var startOfGrid = new Date(firstOfMonth);
        var dow = startOfGrid.getDay();
        var diff = (dow - firstDay + 7) % 7;
        startOfGrid.setDate(startOfGrid.getDate() - diff);
        startOfGrid.setHours(0, 0, 0, 0);

        var dates = [];
        var d = new Date(startOfGrid);
        for (var i = 0; i < 42; i++) {
            dates.push(new Date(d));
            d.setDate(d.getDate() + 1);
        }
        return dates;
    }

    function getEventsForDay(targetDate) {
        var _ = allRawEvents.length; // declare dependency for QML binding
        var dayStart = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());
        var dayEnd = new Date(dayStart);
        dayEnd.setDate(dayEnd.getDate() + 1);
        var dayStartMs = dayStart.getTime();
        var dayEndMs = dayEnd.getTime();

        var events = [];
        for (var i = 0; i < allRawEvents.length; i++) {
            var e = allRawEvents[i];
            var startMs = e.start * 1000;
            var endMs = e.end * 1000;
            if (startMs < dayEndMs && endMs > dayStartMs) {
                events.push({
                    uid: e.uid || "",
                    calendarUid: e.calendar_uid || "",
                    title: e.summary || "Untitled",
                    color: e.color || "",
                    location: e.location || "",
                    description: e.description || "",
                    startTime: new Date(startMs),
                    endTime: new Date(endMs),
                    allDay: (e.end - e.start) >= 86400 && new Date(startMs).getHours() === 0
                });
            }
        }
        events.sort(function(a, b) { return a.startTime.getTime() - b.startTime.getTime(); });
        return events;
    }

    function formatHeaderText(view, date, vDates) {
        if (view === "month") {
            var monthName = I18n.locale().monthName(date.getMonth(), Locale.LongFormat);
            return monthName + " " + date.getFullYear();
        } else if (view === "day") {
            if (!vDates || vDates.length === 0) return "";
            var d = vDates[0];
            return I18n.locale().dayName(d.getDay(), Locale.ShortFormat) + " " +
                   d.getDate() + " " +
                   I18n.locale().monthName(d.getMonth(), Locale.ShortFormat) + " " +
                   d.getFullYear();
        } else if (view === "agenda") {
            return "Upcoming Events";
        } else {
            return formatMonthRangeText(vDates);
        }
    }

    function formatMonthRangeText(dates) {
        if (!dates || dates.length === 0) return "";
        var start = dates[0], end = dates[dates.length - 1];
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
        allRawEvents = events;

        var timedCount = 0, allDayCount = 0;
        var newEvents = [], newAllDayEvents = [], newAgendaEvents = [];
        var vStartDate = new Date(viewStart);
        var vEndDate = new Date(viewEnd);
        var now = new Date();
        now.setHours(0, 0, 0, 0);
        var agendaEnd = new Date(now);
        agendaEnd.setDate(agendaEnd.getDate() + 60);

        for (var i = 0; i < events.length; i++) {
            var event = events[i];
            var start = new Date(event.start * 1000);
            var end = new Date(event.end * 1000);
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
                calendarUid: event.calendar_uid || "",
                color: event.color || ""
            };

            // Time-grid events (week / 4days / day)
            if (currentView !== "agenda" && currentView !== "month") {
                if (start < vEndDate && end > vStartDate) {
                    if (isAllDay) {
                        allDayCount++;
                        newAllDayEvents.push(eventObj);
                    } else {
                        timedCount++;
                        newEvents.push(eventObj);
                    }
                }
            }

            // Agenda / upcoming events
            if (start < agendaEnd && end > now) {
                newAgendaEvents.push(eventObj);
            }
        }

        if (currentView === "agenda" || currentView === "month") {
            timedCount = 0;
            allDayCount = 0;
            for (var n = 0; n < newAgendaEvents.length; n++) {
                if (newAgendaEvents[n].allDay) allDayCount++;
                else timedCount++;
            }
        }

        eventsModel.clear();
        allDayEventsModel.clear();
        for (var j = 0; j < newEvents.length; j++) eventsModel.append(newEvents[j]);
        for (var k = 0; k < newAllDayEvents.length; k++) allDayEventsModel.append(newAllDayEvents[k]);

        newAgendaEvents.sort(function(a, b) { return a.startTime.getTime() - b.startTime.getTime(); });
        agendaEvents.clear();
        for (var m = 0; m < newAgendaEvents.length; m++) agendaEvents.append(newAgendaEvents[m]);

        calculateAllDayEventLayout();
        updateOverlappingEvents();

        return {timedCount: timedCount, allDayCount: allDayCount};
    }

    function calculateAllDayEventLayout() {
        var eventsWithLayout = [];
        for (var i = 0; i < allDayEventsModel.count; i++) {
            var event = allDayEventsModel.get(i);
            var startIdx = Math.max(0, getDayIndexForDate(event.startTime));
            var endIdx = Math.min(viewColumnCount - 1, getDayIndexForDate(event.endTime));
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
        var vs = new Date(viewStart.getFullYear(), viewStart.getMonth(), viewStart.getDate());
        var diff = Math.round((dayDate.getTime() - vs.getTime()) / 86400000);
        return (diff >= 0 && diff < viewColumnCount) ? diff : -1;
    }

    function updateOverlappingEvents() {
        var overlapData = {};
        for (var day = 0; day < viewColumnCount; day++) {
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
            data[eg.index] = { lane: eg.lane, totalLanes: total };
        }
    }

    function navigateWeek(days) {
        var d = new Date(currentDate);
        if (currentView === "day") {
            d.setDate(d.getDate() + (days > 0 ? 1 : -1));
        } else if (currentView === "4days") {
            d.setDate(d.getDate() + (days > 0 ? 4 : -4));
        } else if (currentView === "month") {
            d.setMonth(d.getMonth() + (days > 0 ? 1 : -1));
        } else {
            d.setDate(d.getDate() + days);
        }
        currentDate = d;
        loadEvents();
    }

    function goToToday() {
        currentDate = new Date();
        loadEvents();
    }
}
