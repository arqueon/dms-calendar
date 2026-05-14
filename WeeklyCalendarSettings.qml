import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "weeklyCalendar"

    // Forzamos un Column para que PluginSettings pueda calcular la altura total
    Column {
        width: parent.width
        spacing: Theme.spacingM

        ToggleSetting {
            label: "Use 12-hour format"
            description: "Display time in 12-hour format instead of 24-hour"
            settingKey: "timeFormat"
            defaultValue: false
        }

        SelectionSetting {
            label: "First day of the week"
            description: "Choose which day starts the week in the calendar"
            settingKey: "weekStart"
            defaultValue: "1"
            options: [
                { "label": "Sunday", "value": "0" },
                { "label": "Monday", "value": "1" },
                { "label": "Saturday", "value": "6" }
            ]
        }

        SelectionSetting {
            label: "Line Color"
            description: "Choose the color for grid lines"
            settingKey: "lineColorType"
            defaultValue: "mOutline"
            options: [
                { "label": "Outline", "value": "mOutline" },
                { "label": "On Surface Variant", "value": "mOnSurfaceVariant" }
            ]
        }

        SliderSetting {
            label: "Hour Line Opacity"
            description: "Opacity of the horizontal hour lines"
            settingKey: "hourLineOpacity"
            defaultValue: 50
            minimum: 0
            maximum: 100
        }

        SliderSetting {
            label: "Day Line Opacity"
            description: "Opacity of the vertical day lines"
            settingKey: "dayLineOpacity"
            defaultValue: 90
            minimum: 0
            maximum: 100
        }
    }
}
