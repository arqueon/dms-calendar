import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    property var mainInstance: null

    implicitWidth: 900
    implicitHeight: 650
    width: 900
    height: 650

    property real topHeaderHeight: 60
    property real hourHeight: (mainInstance ? mainInstance.hourHeight : 50)
    property real timeColumnWidth: 65

    // Form local state
    property int  formCalIndex: 0
    property date formSelectedDate: new Date()
    property date datePickerMonth:  new Date()
    property var  datePickerDays: {
        var _dep = mainInstance ? mainInstance.firstDayOfWeek : 1;
        return calcDatePickerDays(datePickerMonth);
    }

    function calcDatePickerDays(month) {
        var fow   = mainInstance ? mainInstance.firstDayOfWeek : 1;
        var first = new Date(month.getFullYear(), month.getMonth(), 1);
        var diff  = (first.getDay() - fow + 7) % 7;
        var start = new Date(first);
        start.setDate(start.getDate() - diff);
        var dates = [], d = new Date(start);
        for (var i = 0; i < 42; i++) {
            dates.push(new Date(d));
            d.setDate(d.getDate() + 1);
        }
        return dates;
    }

    // Reset form fields each time the form opens
    Connections {
        target: mainInstance
        function onShowNewEventFormChanged() {
            if (mainInstance && mainInstance.showNewEventForm) {
                root.formCalIndex     = 0;
                root.formSelectedDate = new Date(mainInstance.currentDate);
                root.datePickerMonth  = new Date(mainInstance.currentDate.getFullYear(),
                                                  mainInstance.currentDate.getMonth(), 1);
                formTitleField.fieldText = "";
                var h = new Date().getHours() + 1;
                if (h >= 24) h = 9;
                var h2 = (h + 1 < 24) ? h + 1 : h;
                formStartField.fieldText = (h  < 10 ? "0" : "") + h  + ":00";
                formEndField.fieldText   = (h2 < 10 ? "0" : "") + h2 + ":00";
            }
        }
    }

    readonly property string currentView: (mainInstance ? mainInstance.currentView : "week")
    readonly property int colCount: (mainInstance ? mainInstance.viewColumnCount : 7)

    function scrollToCurrentTime() {
        if (!mainInstance || !calendarFlickable)
            return;
        var now = new Date();
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        var vStart = new Date(mainInstance.weekStart);
        var vEnd = new Date(vStart);
        vEnd.setDate(vEnd.getDate() + root.colCount);
        if (today >= vStart && today < vEnd) {
            var currentHour = now.getHours() + now.getMinutes() / 60;
            var scrollPos = (currentHour * hourHeight) - (calendarFlickable.height / 2);
            var maxScroll = Math.max(0, (24 * hourHeight) - calendarFlickable.height);
            calendarFlickable.contentY = Math.max(0, Math.min(scrollPos, maxScroll));
        }
    }

    Component.onCompleted: {
        if (mainInstance)
            mainInstance.initializePlugin();
        Qt.callLater(root.scrollToCurrentTime);
    }

    onVisibleChanged: {
        if (visible && mainInstance) {
            mainInstance.loadEvents();
            mainInstance.goToToday();
            Qt.callLater(root.scrollToCurrentTime);
        }
    }

    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
        radius: Appearance.rounding.normal

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.spacing.normal
            spacing: Appearance.spacing.normal

            // ── Header ────────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: topHeaderHeight
                color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.4)
                radius: Appearance.rounding.normal

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Appearance.spacing.normal
                    spacing: Appearance.spacing.small

                    DankIcon {
                        name: "calendar_month"
                        size: 26
                        color: Theme.primary
                    }

                    ColumnLayout {
                        Layout.fillHeight: true
                        spacing: 0

                        StyledText {
                            text: (mainInstance ? mainInstance.monthRangeText : "Calendar")
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        RowLayout {
                            spacing: 4
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: (mainInstance && mainInstance.isLoading ? Theme.error : Theme.primary)
                            }
                            StyledText {
                                text: (mainInstance ? mainInstance.syncStatus : "")
                                font.pixelSize: 11
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // ── View selector ─────────────────────────────────────────
                    Row {
                        spacing: 3

                        Repeater {
                            model: [
                                { label: "Week",   view: "week"   },
                                { label: "4D",     view: "4days"  },
                                { label: "Day",    view: "day"    },
                                { label: "Agenda", view: "agenda" },
                                { label: "Month",  view: "month"  }
                            ]

                            Rectangle {
                                property bool active: root.currentView === modelData.view
                                width: viewLabel.implicitWidth + 14
                                height: 26
                                radius: Appearance.rounding.small
                                color: active
                                    ? Theme.primary
                                    : Theme.withAlpha(Theme.surfaceContainerHigh, 0.7)

                                StyledText {
                                    id: viewLabel
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: 11
                                    font.weight: active ? Font.Bold : Font.Normal
                                    color: active ? Theme.onPrimary : Theme.surfaceText
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (mainInstance) mainInstance.setView(modelData.view); }
                                }
                            }
                        }
                    }

                    // ── New event button ──────────────────────────────────────
                    DankActionButton {
                        iconName: "add"
                        buttonSize: 30
                        onClicked: {
                            if (mainInstance)
                                mainInstance.showNewEventForm = !mainInstance.showNewEventForm;
                        }
                    }

                    // ── Navigation buttons ────────────────────────────────────
                    RowLayout {
                        spacing: Appearance.spacing.small
                        DankActionButton {
                            iconName: "chevron_left"
                            buttonSize: 30
                            onClicked: { if (mainInstance) mainInstance.navigateWeek(-7); }
                        }
                        DankActionButton {
                            iconName: "today"
                            buttonSize: 30
                            onClicked: {
                                if (mainInstance) {
                                    mainInstance.goToToday();
                                    Qt.callLater(root.scrollToCurrentTime);
                                }
                            }
                        }
                        DankActionButton {
                            iconName: "chevron_right"
                            buttonSize: 30
                            onClicked: { if (mainInstance) mainInstance.navigateWeek(7); }
                        }
                        DankActionButton {
                            iconName: "refresh"
                            buttonSize: 30
                            enabled: (mainInstance ? !mainInstance.isLoading : false)
                            onClicked: { if (mainInstance) mainInstance.loadEvents(); }
                        }
                    }
                }
            }

            // ── Content area ──────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.2)
                radius: Appearance.rounding.normal
                clip: true

                // ── TIME GRID (week / 4days / day) ────────────────────────────
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    visible: !mainInstance.showNewEventForm && (root.currentView === "week" || root.currentView === "4days" || root.currentView === "day")

                    // Day-of-week sticky header
                    Row {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36

                        // Spacer for time column
                        Item { width: root.timeColumnWidth; height: 36 }

                        // Day name + number cells
                        Row {
                            width: parent.width - root.timeColumnWidth
                            height: 36

                            Repeater {
                                model: root.colCount

                                Item {
                                    width: parent.width / root.colCount
                                    height: 36

                                    property var dayDate: (mainInstance && mainInstance.viewDates.length > index
                                        ? mainInstance.viewDates[index] : new Date())

                                    property bool isToday: {
                                        var n = new Date();
                                        return dayDate.getFullYear() === n.getFullYear()
                                            && dayDate.getMonth() === n.getMonth()
                                            && dayDate.getDate() === n.getDate();
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 1

                                        StyledText {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: I18n.locale().dayName(dayDate.getDay(), Locale.NarrowFormat)
                                            font.pixelSize: 10
                                            color: isToday ? Theme.primary : Theme.surfaceVariantText
                                        }

                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 22; height: 22; radius: 11
                                            color: isToday ? Theme.primary : "transparent"

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: dayDate.getDate().toString()
                                                font.pixelSize: 11
                                                font.weight: isToday ? Font.Bold : Font.Normal
                                                color: isToday ? Theme.onPrimary : Theme.surfaceText
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Scrollable hour grid
                    DankFlickable {
                        id: calendarFlickable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: 24 * root.hourHeight
                        clip: true

                        Item {
                            width: parent.width
                            height: 24 * root.hourHeight

                            Row {
                                anchors.fill: parent

                                // Time labels
                                Column {
                                    width: root.timeColumnWidth
                                    Repeater {
                                        model: 24
                                        Rectangle {
                                            width: root.timeColumnWidth
                                            height: root.hourHeight
                                            color: "transparent"
                                            StyledText {
                                                text: (index < 10 ? "0" : "") + index + ":00"
                                                anchors.right: parent.right
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.top
                                                font.pixelSize: 10
                                                color: Theme.surfaceVariantText
                                            }
                                        }
                                    }
                                }

                                // Day columns + events
                                Item {
                                    width: parent.width - root.timeColumnWidth
                                    height: parent.height

                                    // Horizontal hour lines
                                    Repeater {
                                        model: 25
                                        Rectangle {
                                            width: parent.width; height: 1
                                            y: index * root.hourHeight
                                            color: Theme.outline
                                            opacity: 0.2
                                        }
                                    }

                                    // Vertical day separators
                                    Row {
                                        anchors.fill: parent
                                        Repeater {
                                            model: root.colCount
                                            Rectangle {
                                                width: parent.width / root.colCount
                                                height: parent.height
                                                color: "transparent"
                                                border.color: Theme.outline
                                                border.width: 0.5
                                                opacity: 0.3
                                            }
                                        }
                                    }

                                    // Timed events
                                    Repeater {
                                        model: (mainInstance ? mainInstance.eventsModel : null)
                                        delegate: Rectangle {
                                            property var overlap: (mainInstance && mainInstance.overlappingEventsData && mainInstance.overlappingEventsData[index]
                                                ? mainInstance.overlappingEventsData[index]
                                                : { lane: 0, totalLanes: 1 })
                                            property int dayIdx: (mainInstance ? mainInstance.getDayIndexForDate(model.startTime) : -1)
                                            property real colWidth: parent.width / root.colCount

                                            visible: dayIdx >= 0 && dayIdx < root.colCount
                                            x: dayIdx * colWidth + (overlap.lane / overlap.totalLanes) * colWidth + 2
                                            y: (model.startTime.getHours() + model.startTime.getMinutes() / 60) * root.hourHeight
                                            width: (colWidth / overlap.totalLanes) - 4
                                            height: Math.max(20, ((model.endTime - model.startTime) / 3600000) * root.hourHeight)

                                            color: (model.color !== "" ? Theme.withAlpha(Qt.color(model.color), 0.45) : Theme.primaryContainer)
                                            radius: 4
                                            border.color: (model.color !== "" ? model.color : Theme.primary)
                                            clip: true

                                            Column {
                                                anchors.fill: parent
                                                anchors.margins: 4
                                                spacing: 2
                                                StyledText {
                                                    text: model.title
                                                    font.pixelSize: 11; font.weight: Font.Bold
                                                    color: Theme.surfaceText
                                                    elide: Text.ElideRight; width: parent.width
                                                }
                                                StyledText {
                                                    text: Qt.formatTime(model.startTime, "hh:mm")
                                                    font.pixelSize: 9
                                                    color: Theme.surfaceText; opacity: 0.9
                                                }
                                            }

                                            ToolTip.visible: evtMouse.containsMouse
                                            ToolTip.text: model.title + "\n" + model.location +
                                                          (model.description ? "\n\n" + model.description : "")

                                            MouseArea {
                                                id: evtMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: { if (mainInstance) mainInstance.openEventInCalendar(model.calendarUid, model.id); }
                                            }
                                        }
                                    }

                                    // Current-time indicator
                                    Rectangle {
                                        property var now: new Date()
                                        property int curDay: (mainInstance ? mainInstance.getDayIndexForDate(now) : -1)
                                        visible: curDay >= 0 && curDay < root.colCount
                                        x: curDay * (parent.width / root.colCount)
                                        y: (now.getHours() + now.getMinutes() / 60) * root.hourHeight
                                        width: parent.width / root.colCount
                                        height: 2
                                        color: Theme.error
                                        z: 5
                                    }
                                }
                            }
                        }
                    }
                }

                // ── AGENDA VIEW ───────────────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: !mainInstance.showNewEventForm && root.currentView === "agenda"

                    // Empty-state message
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Appearance.spacing.small
                        visible: (mainInstance ? mainInstance.agendaEvents.count === 0 : true)

                        DankIcon {
                            name: "event_available"
                            size: 48
                            color: Theme.surfaceVariantText
                            Layout.alignment: Qt.AlignHCenter
                        }
                        StyledText {
                            text: "No upcoming events"
                            font.pixelSize: 14
                            color: Theme.surfaceVariantText
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }

                    ListView {
                        anchors.fill: parent
                        anchors.margins: Appearance.spacing.normal
                        model: (mainInstance ? mainInstance.agendaEvents : null)
                        clip: true
                        spacing: Appearance.spacing.small

                        delegate: Rectangle {
                            width: parent ? parent.width : 0
                            height: agendaContent.implicitHeight + Appearance.spacing.normal
                            color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.3)
                            radius: Appearance.rounding.small

                            ToolTip.visible: agendaMouse.containsMouse && model.description !== ""
                            ToolTip.delay: 600
                            ToolTip.text: model.description

                            MouseArea {
                                id: agendaMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { if (mainInstance) mainInstance.openEventInCalendar(model.calendarUid, model.id); }
                            }

                            RowLayout {
                                id: agendaContent
                                anchors {
                                    left: parent.left; right: parent.right
                                    top: parent.top
                                    margins: Appearance.spacing.small
                                }
                                spacing: Appearance.spacing.small

                                Rectangle {
                                    width: 4
                                    height: agendaText.implicitHeight
                                    radius: 2
                                    color: (model.color !== "" ? model.color : Theme.primary)
                                }

                                ColumnLayout {
                                    id: agendaText
                                    Layout.fillWidth: true
                                    spacing: 2

                                    StyledText {
                                        text: model.title
                                        font.pixelSize: 13; font.weight: Font.Medium
                                        color: Theme.surfaceText
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    StyledText {
                                        text: model.allDay
                                            ? Qt.formatDate(model.startTime, "ddd d MMM") + " · All day"
                                            : Qt.formatDate(model.startTime, "ddd d MMM") + " · " +
                                              Qt.formatTime(model.startTime, "hh:mm") + " – " +
                                              Qt.formatTime(model.endTime, "hh:mm")
                                        font.pixelSize: 11
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: model.location
                                        font.pixelSize: 11
                                        color: Theme.surfaceVariantText
                                        visible: model.location !== ""
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }

                // ── MONTH VIEW ────────────────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: !mainInstance.showNewEventForm && root.currentView === "month"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Appearance.spacing.small
                        spacing: 2

                        // Day-of-week header row
                        Row {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22

                            Repeater {
                                model: 7
                                StyledText {
                                    width: parent.width / 7
                                    text: I18n.locale().dayName(
                                        (index + (mainInstance ? mainInstance.firstDayOfWeek : 1)) % 7,
                                        Locale.NarrowFormat)
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: 11; font.weight: Font.Bold
                                    color: Theme.surfaceVariantText
                                }
                            }
                        }

                        // 6×7 month grid
                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 7
                            rowSpacing: 2
                            columnSpacing: 2

                            Repeater {
                                model: (mainInstance && root.currentView === "month"
                                    ? mainInstance.monthGridDates.length : 0)

                                Rectangle {
                                    property var cellDate: (mainInstance && mainInstance.monthGridDates.length > index
                                        ? mainInstance.monthGridDates[index] : new Date())

                                    property bool isCurrentMonth: cellDate.getMonth() ===
                                        (mainInstance ? mainInstance.currentDate.getMonth() : -1)

                                    property bool isToday: {
                                        var n = new Date();
                                        return cellDate.getFullYear() === n.getFullYear()
                                            && cellDate.getMonth() === n.getMonth()
                                            && cellDate.getDate() === n.getDate();
                                    }

                                    // Re-evaluate when events change
                                    property var dayEvents: {
                                        var _dep = mainInstance ? mainInstance.allRawEvents.length : 0;
                                        return mainInstance ? mainInstance.getEventsForDay(cellDate) : [];
                                    }

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    color: isToday
                                        ? Theme.withAlpha(Theme.primary, 0.15)
                                        : isCurrentMonth
                                            ? Theme.withAlpha(Theme.surfaceContainerHigh, 0.35)
                                            : Theme.withAlpha(Theme.surfaceContainer, 0.1)

                                    radius: Appearance.rounding.small
                                    border.color: isToday ? Theme.primary : "transparent"
                                    border.width: isToday ? 1 : 0

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        spacing: 1

                                        StyledText {
                                            Layout.alignment: Qt.AlignRight
                                            text: cellDate.getDate().toString()
                                            font.pixelSize: 11
                                            font.weight: isToday ? Font.Bold : Font.Normal
                                            color: isToday ? Theme.primary
                                                : isCurrentMonth ? Theme.surfaceText
                                                : Theme.surfaceVariantText
                                        }

                                        Repeater {
                                            model: Math.min(dayEvents.length, 3)
                                            Rectangle {
                                                property var ev: dayEvents[index]
                                                Layout.fillWidth: true
                                                height: 15
                                                radius: 3
                                                color: ev.color !== ""
                                                    ? Theme.withAlpha(Qt.color(ev.color), 0.75)
                                                    : Theme.withAlpha(Theme.primary, 0.75)
                                                clip: true

                                                StyledText {
                                                    anchors {
                                                        left: parent.left; right: parent.right
                                                        verticalCenter: parent.verticalCenter
                                                        leftMargin: 3; rightMargin: 3
                                                    }
                                                    text: ev.title
                                                    font.pixelSize: 10
                                                    color: Theme.surfaceText
                                                    elide: Text.ElideRight
                                                    wrapMode: Text.NoWrap
                                                    maximumLineCount: 1
                                                }

                                                ToolTip.visible: pillMouse.containsMouse
                                                ToolTip.delay: 600
                                                ToolTip.text: {
                                                    var t = ev.title;
                                                    t += "\n" + (ev.allDay
                                                        ? Qt.formatDate(ev.startTime, "ddd d MMM") + " · All day"
                                                        : Qt.formatDate(ev.startTime, "ddd d MMM") + " · " +
                                                          Qt.formatTime(ev.startTime, "hh:mm") + " – " +
                                                          Qt.formatTime(ev.endTime, "hh:mm"));
                                                    if (ev.location !== "") t += "\n" + ev.location;
                                                    if (ev.description !== "") t += "\n\n" + ev.description;
                                                    return t;
                                                }

                                                MouseArea {
                                                    id: pillMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: { if (mainInstance) mainInstance.openEventInCalendar(ev.calendarUid, ev.uid); }
                                                }
                                            }
                                        }

                                        StyledText {
                                            visible: dayEvents.length > 3
                                            text: "+" + (dayEvents.length - 3) + " more"
                                            font.pixelSize: 10
                                            color: Theme.surfaceVariantText
                                        }

                                        Item { Layout.fillHeight: true }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── NEW EVENT FORM ────────────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: mainInstance ? mainInstance.showNewEventForm : false

                    // helper component: labelled text input
                    component FieldBox: Rectangle {
                        property alias fieldText: fi.text
                        property string placeholder: ""
                        property int fieldWidth: 0
                        Layout.fillWidth: fieldWidth === 0
                        Layout.preferredWidth: fieldWidth > 0 ? fieldWidth : -1
                        height: 36
                        color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.6)
                        radius: Appearance.rounding.small
                        border.color: fi.activeFocus ? Theme.primary
                                                     : Theme.withAlpha(Theme.outline, 0.8)
                        border.width: fi.activeFocus ? 2 : 1

                        TextInput {
                            id: fi
                            anchors { fill: parent; margins: 10 }
                            color: Theme.surfaceText
                            font.pixelSize: 13
                            selectionColor: Theme.withAlpha(Theme.primary, 0.35)
                            selectedTextColor: Theme.surfaceText
                            clip: true

                            Text {
                                anchors.fill: parent
                                text: parent.parent.placeholder
                                color: Theme.surfaceVariantText
                                font.pixelSize: 13
                                visible: parent.text === ""
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 2 * Appearance.spacing.large
                        spacing: Appearance.spacing.small

                        // ── Form header ──
                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                text: "New Event"
                                font.pixelSize: 16; font.weight: Font.Bold
                                color: Theme.surfaceText
                            }
                            Item { Layout.fillWidth: true }
                            DankActionButton {
                                iconName: "close"; buttonSize: 28
                                onClicked: { if (mainInstance) mainInstance.showNewEventForm = false; }
                            }
                        }

                        // ── Title ──
                        StyledText { text: "Title"; font.pixelSize: 11; color: Theme.surfaceVariantText }
                        FieldBox {
                            id: formTitleField
                            placeholder: "Event title"
                        }

                        // ── Date picker + Start / End ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            // Date picker button + popup
                            ColumnLayout {
                                spacing: 4
                                Layout.fillWidth: true

                                StyledText { text: "Date"; font.pixelSize: 11; color: Theme.surfaceVariantText }

                                Rectangle {
                                    id: datePickerBtn
                                    Layout.fillWidth: true
                                    height: 36
                                    color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.6)
                                    radius: Appearance.rounding.small
                                    border.color: Theme.withAlpha(Theme.outline, 0.8)
                                    border.width: 1

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                        spacing: 6
                                        DankIcon { name: "calendar_month"; size: 15; color: Theme.surfaceVariantText }
                                        StyledText {
                                            text: Qt.formatDate(root.formSelectedDate, "ddd d MMM yyyy")
                                            font.pixelSize: 12; color: Theme.surfaceText
                                            Layout.fillWidth: true
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: datePickerPopup.open()
                                    }

                                    Popup {
                                        id: datePickerPopup
                                        x: 0
                                        y: datePickerBtn.height + 2
                                        width: 280
                                        padding: 8
                                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                                        background: Rectangle {
                                            color: Theme.surfaceContainerHigh
                                            radius: Appearance.rounding.normal
                                            border.color: Theme.outline; border.width: 1
                                        }

                                        contentItem: ColumnLayout {
                                            spacing: 4

                                            // Month navigation
                                            RowLayout {
                                                Layout.fillWidth: true
                                                DankActionButton {
                                                    iconName: "chevron_left"; buttonSize: 26
                                                    onClicked: {
                                                        var d = new Date(root.datePickerMonth);
                                                        d.setMonth(d.getMonth() - 1);
                                                        root.datePickerMonth = d;
                                                    }
                                                }
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    horizontalAlignment: Text.AlignHCenter
                                                    text: I18n.locale().monthName(root.datePickerMonth.getMonth(), Locale.LongFormat)
                                                          + " " + root.datePickerMonth.getFullYear()
                                                    font.pixelSize: 13; font.weight: Font.Bold
                                                    color: Theme.surfaceText
                                                }
                                                DankActionButton {
                                                    iconName: "chevron_right"; buttonSize: 26
                                                    onClicked: {
                                                        var d = new Date(root.datePickerMonth);
                                                        d.setMonth(d.getMonth() + 1);
                                                        root.datePickerMonth = d;
                                                    }
                                                }
                                            }

                                            // Day-of-week header
                                            Row {
                                                Layout.fillWidth: true
                                                Repeater {
                                                    model: 7
                                                    StyledText {
                                                        width: (264) / 7
                                                        text: I18n.locale().dayName(
                                                            (index + (mainInstance ? mainInstance.firstDayOfWeek : 1)) % 7,
                                                            Locale.NarrowFormat)
                                                        horizontalAlignment: Text.AlignHCenter
                                                        font.pixelSize: 10; font.weight: Font.Bold
                                                        color: Theme.surfaceVariantText
                                                    }
                                                }
                                            }

                                            // 6×7 day grid
                                            GridLayout {
                                                columns: 7
                                                rowSpacing: 2; columnSpacing: 2
                                                Layout.fillWidth: true

                                                Repeater {
                                                    model: root.datePickerDays.length

                                                    Rectangle {
                                                        property var  cellDate:   root.datePickerDays[index]
                                                        property bool inMonth:    cellDate.getMonth() === root.datePickerMonth.getMonth()
                                                        property bool isSelected: cellDate.toDateString() === root.formSelectedDate.toDateString()
                                                        property bool isToday:    cellDate.toDateString() === new Date().toDateString()

                                                        width: 264 / 7; height: width; radius: width / 2
                                                        color: isSelected ? Theme.primary
                                                             : isToday    ? Theme.withAlpha(Theme.primary, 0.2)
                                                             : "transparent"

                                                        StyledText {
                                                            anchors.centerIn: parent
                                                            text: cellDate.getDate().toString()
                                                            font.pixelSize: 11
                                                            font.weight: isSelected || isToday ? Font.Bold : Font.Normal
                                                            color: isSelected ? Theme.onPrimary
                                                                 : inMonth    ? Theme.surfaceText
                                                                 : Theme.surfaceVariantText
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                root.formSelectedDate = new Date(cellDate);
                                                                root.datePickerMonth  = new Date(
                                                                    cellDate.getFullYear(), cellDate.getMonth(), 1);
                                                                datePickerPopup.close();
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            // Today shortcut
                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 28; radius: Appearance.rounding.small
                                                color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.6)

                                                StyledText {
                                                    anchors.centerIn: parent; text: "Today"
                                                    font.pixelSize: 11; color: Theme.primary
                                                }
                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        var today = new Date();
                                                        root.formSelectedDate = today;
                                                        root.datePickerMonth  = new Date(today.getFullYear(), today.getMonth(), 1);
                                                        datePickerPopup.close();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                spacing: 4
                                StyledText { text: "Start"; font.pixelSize: 11; color: Theme.surfaceVariantText }
                                FieldBox { id: formStartField; fieldWidth: 72; placeholder: "09:00" }
                            }
                            ColumnLayout {
                                spacing: 4
                                StyledText { text: "End"; font.pixelSize: 11; color: Theme.surfaceVariantText }
                                FieldBox { id: formEndField; fieldWidth: 72; placeholder: "10:00" }
                            }
                        }

                        // ── Calendar selector ──
                        StyledText { text: "Calendar"; font.pixelSize: 11; color: Theme.surfaceVariantText }

                        Rectangle {
                            id: calDropdown
                            Layout.fillWidth: true
                            height: 36
                            color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.6)
                            radius: Appearance.rounding.small
                            border.color: Theme.withAlpha(Theme.outline, 0.8)
                            border.width: 1

                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                spacing: 8

                                Rectangle {
                                    width: 12; height: 12; radius: 6
                                    color: {
                                        var cals = mainInstance ? mainInstance.calendars : [];
                                        return (cals.length > root.formCalIndex && cals[root.formCalIndex].color)
                                            ? cals[root.formCalIndex].color : Theme.primary;
                                    }
                                }

                                StyledText {
                                    text: {
                                        var cals = mainInstance ? mainInstance.calendars : [];
                                        return cals.length > root.formCalIndex
                                            ? cals[root.formCalIndex].name : "No calendars";
                                    }
                                    font.pixelSize: 13; color: Theme.surfaceText
                                    Layout.fillWidth: true
                                }

                                DankIcon { name: "expand_more"; size: 16; color: Theme.surfaceVariantText }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calPopup.open()
                            }

                            Popup {
                                id: calPopup
                                x: 0
                                y: calDropdown.height + 2
                                width: calDropdown.width
                                padding: 4
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                                background: Rectangle {
                                    color: Theme.surfaceContainerHigh
                                    radius: Appearance.rounding.small
                                    border.color: Theme.outline; border.width: 1
                                }

                                contentItem: ListView {
                                    implicitHeight: Math.min(contentHeight, 180)
                                    model: mainInstance ? mainInstance.calendars : []
                                    clip: true

                                    delegate: Rectangle {
                                        width: ListView.view ? ListView.view.width : 0
                                        height: 36
                                        color: optMouse.containsMouse
                                            ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                                        radius: 4

                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                            spacing: 8
                                            Rectangle {
                                                width: 12; height: 12; radius: 6
                                                color: modelData.color ? modelData.color : Theme.primary
                                            }
                                            StyledText {
                                                text: modelData.name
                                                font.pixelSize: 13; color: Theme.surfaceText
                                                Layout.fillWidth: true
                                            }
                                        }

                                        MouseArea {
                                            id: optMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                root.formCalIndex = index;
                                                calPopup.close();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── Status / error ──
                        StyledText {
                            visible: mainInstance ? mainInstance.createEventStatus !== "" : false
                            text: mainInstance ? mainInstance.createEventStatus : ""
                            font.pixelSize: 11
                            color: (mainInstance && mainInstance.createEventStatus.startsWith("Error"))
                                ? Theme.error : Theme.surfaceVariantText
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        // ── Buttons ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small
                            Item { Layout.fillWidth: true }

                            Rectangle {
                                width: 90; height: 34; radius: Appearance.rounding.small
                                color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.8)
                                border.color: Theme.outline; border.width: 1
                                StyledText {
                                    anchors.centerIn: parent; text: "Cancel"
                                    font.pixelSize: 13; color: Theme.surfaceText
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (mainInstance) mainInstance.showNewEventForm = false; }
                                }
                            }

                            Rectangle {
                                width: 90; height: 34; radius: Appearance.rounding.small
                                color: formTitleField.fieldText.trim() !== ""
                                    ? Theme.primary : Theme.withAlpha(Theme.primary, 0.4)
                                StyledText {
                                    anchors.centerIn: parent; text: "Create"
                                    font.pixelSize: 13; font.weight: Font.Bold
                                    color: Theme.onPrimary
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!mainInstance) return;
                                        var title = formTitleField.fieldText.trim();
                                        if (title === "") return;
                                        var cals = mainInstance.calendars;
                                        var uid = (cals && cals.length > root.formCalIndex)
                                            ? cals[root.formCalIndex].uid : "";
                                        mainInstance.createEvent(
                                            title,
                                            Qt.formatDate(root.formSelectedDate, "yyyy-MM-dd"),
                                            formStartField.fieldText,
                                            formEndField.fieldText,
                                            uid
                                        );
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
