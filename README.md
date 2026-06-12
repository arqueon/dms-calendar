# Calendar for Dank Material Shell (DMS)

A Material 3 styled calendar widget for Dank Material Shell, ported and enhanced from the Noctalia Shell ecosystem. It integrates natively with **Evolution Data Server (EDS)** to sync your local and cloud calendars (Google, Nextcloud, CalDAV, etc.) directly into your desktop shell.

<img width="1084" height="802" alt="image" src="https://github.com/user-attachments/assets/cb3352b0-addb-43a4-a89c-b3ce011a29f0" />

## Features

### Five Calendar Views

Switch between views using the buttons in the header bar:

| View | Description |
|------|-------------|
| **Week** | Classic 7-column time grid showing the full current week. |
| **4 Days** | Compact time grid showing 4 days starting from the current date — useful on narrower displays or to focus on the near future. |
| **Day** | Single-column time grid for the selected day, with maximum space for event detail. |
| **Agenda** | Chronological flat list of upcoming events for the next 60 days, grouped with date and time. Ideal for a quick overview without the grid. |
| **Month** | Traditional monthly calendar grid (6 weeks × 7 days). Each day cell shows up to 3 event pills with their title and calendar colour, plus a `+N more` indicator if there are additional events. |

Navigation arrows in the header move by the appropriate unit for each view (±1 day, ±4 days, ±1 week or ±1 month). The **Today** button always returns to the current date regardless of view.

### Other Features

- **DMS Native Aesthetics**: Full support for DMS Theme tokens, including dynamic transparency and background blur.
- **Smart Overlap Management**: Concurrent events are displayed side-by-side (lanes) automatically.
- **Calendar Colors**: Each event uses the color defined in your Evolution/GNOME calendars.
- **Click to Open**: Click any event to open it directly in Evolution (opens the specific event dialog) or in GNOME Calendar as a fallback.
- **Tooltips**: Hover over any event to see its full title, time, location and description.
- **Event Creation**: Create new events directly from the widget — pick a calendar, set a date via the mini date-picker, enter title and start/end times, and save.
- **Persistent Cache**: Instant loading from local cache while background sync happens.
- **Integrated Settings**: Configure first day of the week, 12h/24h format and UI opacities via DMS Settings.

## Requirements

### Mandatory

- **Dank Material Shell** >= 1.2.0
- **evolution-data-server**: Backend service that provides the calendar data.
- **python-dateutil**: Python library used for recurrence rule handling.
- **libical**: ICalGLib introspection libraries for calendar parsing.

```bash
# Arch / CachyOS
sudo pacman -S evolution-data-server python-dateutil libical
```

### Optional — Calendar Client

When you click an event, the plugin tries to open it in a calendar app. Two options:

| App | Behaviour | Install |
|-----|-----------|---------|
| **Evolution** *(recommended)* | Opens the specific event dialog directly via `calendar://?source-uid=…&comp-uid=…` | `sudo pacman -S evolution` |
| **GNOME Calendar** *(fallback)* | Opens the app at today's view (no deep-link to the specific event) | `sudo pacman -S gnome-calendar` |

If neither is installed, the click is silently ignored. If both are installed, Evolution takes priority (you can change the command in `WeeklyCalendar.qml` → `openCalendarProcess`).

## Calendar Configuration

The plugin reads data from Evolution Data Server. You can add calendars in several ways:

1. **GNOME Online Accounts**: Add Google, Microsoft or Nextcloud accounts via `gnome-control-center` → Online Accounts.
2. **Evolution client**: Add CalDAV, ICS or Webcal sources directly in the Evolution app.
3. **Standalone GOA** (without full GNOME): Install `gnome-online-accounts` + `gnome-control-center` to manage accounts in other window managers (e.g. Niri). Once installed, you can execute it from Niri using the command:
   ```bash
   XDG_CURRENT_DESKTOP=GNOME gnome-control-center
   ```

Once an account is enabled, the plugin detects and syncs it automatically on next load.

## Installation

1. Clone into your DMS plugins directory:
   ```bash
   git clone https://github.com/arqueon/dms-calendar ~/.config/DankMaterialShell/plugins/weeklyCalendar
   ```
2. Enable the plugin in DMS Settings or in `plugin_settings.json`:
   ```json
   "weeklyCalendar": { "enabled": true }
   ```
3. Add the widget to your bar in `settings.json`:
   ```json
   { "id": "weeklyCalendar", "enabled": true }
   ```

## Credits & Attribution

This plugin is a port and enhancement of the [Weekly Calendar](https://github.com/noctalia-dev/noctalia-plugins/tree/main/weekly-calendar) plugin by **dodaars** for Noctalia Shell.

Key changes for DMS:
- Five-view selector (Week / 4 Days / Day / Agenda / Month).
- Complete restyling to use DMS `Theme` and `Appearance` singletons.
- Adaptation to DMS `PluginComponent` and `PluginSettings` architecture.
- `DankPopout` integration for the detail view.
- Support for `ICalGLib 4.0` introspection.
- Evolution deep-link on event click (`calendar://?source-uid=…&comp-uid=…`).
- Inline event creation form with mini date-picker and calendar selector.

## License

GPL-3.0
