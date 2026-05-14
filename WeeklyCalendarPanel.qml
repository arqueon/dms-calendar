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
    
    // Dimensiones fijas para el Popout
    implicitWidth: 900
    implicitHeight: 650
    width: 900
    height: 650

    property real topHeaderHeight: 60
    property real hourHeight: (mainInstance ? mainInstance.hourHeight : 50)
    property real timeColumnWidth: 65
    property real daySpacing: 1

    function scrollToCurrentTime() {
        if (!mainInstance || !calendarFlickable)
            return ;

        var now = new Date();
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        var weekStart = new Date(mainInstance.weekStart);
        var weekEnd = new Date(weekStart.getFullYear(), weekStart.getMonth(), weekStart.getDate() + 7);
        if (today >= weekStart && today < weekEnd) {
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

    // Fondo principal con transparencia coordinada con el sistema
    Rectangle {
        id: panelContainer
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
        radius: Appearance.rounding.normal

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.spacing.normal
            spacing: Appearance.spacing.normal

            // Header Section
            Rectangle {
                id: header
                Layout.fillWidth: true
                Layout.preferredHeight: topHeaderHeight
                color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.4)
                radius: Appearance.rounding.normal

                RowLayout {
                    anchors.margins: Appearance.spacing.normal
                    anchors.fill: parent

                    DankIcon {
                        name: "calendar_view_week"
                        size: 32
                        color: Theme.primary
                    }

                    ColumnLayout {
                        Layout.fillHeight: true
                        spacing: 0

                        StyledText {
                            text: "Weekly Calendar"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        RowLayout {
                            spacing: Appearance.spacing.small

                            StyledText {
                                text: (mainInstance ? mainInstance.monthRangeText : "")
                                font.pixelSize: 12
                                color: Theme.surfaceVariantText
                            }

                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 4
                                color: (mainInstance && mainInstance.isLoading ? Theme.error : Theme.primary)
                            }

                            StyledText {
                                text: (mainInstance ? mainInstance.syncStatus : "")
                                font.pixelSize: 12
                                color: Theme.surfaceVariantText
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: Appearance.spacing.small
                        DankActionButton {
                            iconName: "chevron_left"
                            buttonSize: 32
                            onClicked: { if (mainInstance) mainInstance.navigateWeek(-7); }
                        }
                        DankActionButton {
                            iconName: "today"
                            buttonSize: 32
                            onClicked: { if (mainInstance) { mainInstance.goToToday(); Qt.callLater(root.scrollToCurrentTime); } }
                        }
                        DankActionButton {
                            iconName: "chevron_right"
                            buttonSize: 32
                            onClicked: { if (mainInstance) mainInstance.navigateWeek(7); }
                        }
                        DankActionButton {
                            iconName: "refresh"
                            buttonSize: 32
                            enabled: (mainInstance ? !mainInstance.isLoading : false)
                            onClicked: { if (mainInstance) mainInstance.loadEvents(); }
                        }
                    }
                }
            }

            // Grid de Calendario
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.2)
                radius: Appearance.rounding.normal
                clip: true

                DankFlickable {
                    id: calendarFlickable
                    anchors.fill: parent
                    contentHeight: 24 * root.hourHeight
                    clip: true

                    Item {
                        id: gridContainer
                        width: parent.width
                        height: 24 * root.hourHeight

                        Row {
                            anchors.fill: parent
                            
                            // Time Column
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

                            // Days Grid
                            Item {
                                width: parent.width - root.timeColumnWidth
                                height: parent.height

                                // Lineas Horizontales
                                Repeater {
                                    model: 25
                                    Rectangle {
                                        width: parent.width; height: 1
                                        y: index * root.hourHeight
                                        color: Theme.outline
                                        opacity: 0.2
                                    }
                                }

                                // Columnas de Días
                                Row {
                                    anchors.fill: parent
                                    Repeater {
                                        model: 7
                                        Rectangle {
                                            width: (parent.width / 7)
                                            height: parent.height
                                            color: "transparent"
                                            border.color: Theme.outline
                                            border.width: 0.5
                                            opacity: 0.3
                                        }
                                    }
                                }

                                // Eventos con Soporte de Superposición
                                Repeater {
                                    model: (mainInstance ? mainInstance.eventsModel : null)
                                    delegate: Rectangle {
                                        property var overlap: (mainInstance && mainInstance.overlappingEventsData && mainInstance.overlappingEventsData[index] ? mainInstance.overlappingEventsData[index] : { lane: 0, totalLanes: 1 })
                                        property int dayIdx: (mainInstance ? mainInstance.getDayIndexForDate(model.startTime) : -1)
                                        property real colWidth: (parent.width / 7)
                                        
                                        visible: dayIdx >= 0 && dayIdx < 7
                                        x: dayIdx * colWidth + (overlap.lane / overlap.totalLanes) * colWidth + 2
                                        y: (model.startTime.getHours() + model.startTime.getMinutes()/60) * root.hourHeight
                                        width: (colWidth / overlap.totalLanes) - 4
                                        height: Math.max(20, ((model.endTime - model.startTime) / 3600000) * root.hourHeight)
                                        
                                        color: (model.color !== "" ? Theme.withAlpha(Qt.color(model.color), 0.45) : Theme.primaryContainer)
                                        radius: 4
                                        border.color: (model.color !== "" ? model.color : Theme.primary)
                                        clip: true

                                        Column {
                                            anchors.fill: parent; anchors.margins: 4
                                            spacing: 2
                                            StyledText {
                                                text: model.title; font.pixelSize: 11; font.weight: Font.Bold
                                                color: Theme.surfaceText; elide: Text.ElideRight; width: parent.width
                                            }
                                            StyledText {
                                                text: Qt.formatTime(model.startTime, "hh:mm"); font.pixelSize: 9
                                                color: Theme.surfaceText; opacity: 0.9
                                            }
                                        }
                                        
                                        // Tooltip básico
                                        ToolTip.visible: mouseArea.containsMouse
                                        ToolTip.text: model.title + "\n" + model.location + (model.description ? "\n\n" + model.description : "")
                                        
                                        MouseArea {
                                            id: mouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                        }
                                    }
                                }
                                
                                // Indicador de hora actual
                                Rectangle {
                                    property var now: new Date()
                                    property int curDay: (mainInstance ? mainInstance.getDayIndexForDate(now) : -1)
                                    visible: curDay >= 0 && curDay < 7
                                    x: curDay * (parent.width / 7)
                                    y: (now.getHours() + now.getMinutes()/60) * root.hourHeight
                                    width: (parent.width / 7); height: 2
                                    color: Theme.error; z: 5
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
