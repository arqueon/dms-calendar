# Calendar for Dank Material Shell (DMS)

A comprehensive, Material 3 styled weekly calendar widget for Dank Material Shell, ported and enhanced from the Noctalia Shell ecosystem. It integrates natively with **Evolution Data Server (EDS)** to sync your local and cloud calendars (Google, Nextcloud, CalDAV, etc.) directly into your desktop shell.

<img width="1084" height="802" alt="image" src="https://github.com/user-attachments/assets/7131bdb6-b4c8-401d-b229-e0f85687bb43" />

## Features

- **Weekly Grid View**: Clear 7-day visualization of your schedule.
- **DMS Native Aesthetics**: Full support for DMS Theme tokens, including dynamic transparency and background blur.
- **Smart Overlap Management**: Automatically detects concurrent events and displays them side-by-side (lanes) for maximum readability.
- **Color Distinguishability**: Fetches and uses the specific colors defined in your Evolution/GNOME calendars.
- **Interactive**: Click any event to open it in GNOME Calendar or Evolution.
- **Persistent Cache**: Instant loading using local cache while background synchronization happens.
- **Integrated Settings**: Configure first day of the week, 12h/24h format, and UI opacities via DMS Settings.

## Requirements

The plugin requires the following system dependencies:

- **Dank Material Shell** >= 1.2.0
- **evolution-data-server**: Backend service for calendar data.
- **python-dateutil**: Python library for recurrence handling.
- **libical**: (ICalGLib) Introspection libraries for calendar parsing.

### Arch / CachyOS Installation:
```bash
sudo pacman -S evolution-data-server python-dateutil libical
```

## Calendar Configuration

This plugin reads data from the Evolution Data Server. You can manage your calendars in several ways:

1.  **GNOME Online Accounts**: If you use GNOME or have `gnome-control-center` installed, add your Google, Microsoft, or Nextcloud accounts there.
2.  **Evolution**: Install the `evolution` mail/calendar client to add CalDAV, ICS, or Webcal links.
3.  **Standalone GOA (without full GNOME)**: You can install `gnome-online-accounts` and `gnome-control-center` to manage accounts in other window managers like Niri.

Once an account is enabled in your system's "Online Accounts" or Evolution, this plugin will detect and sync it automatically.

## Installation

1.  Clone this repository into your DMS plugins directory:
    ```bash
    git clone https://github.com/yourusername/dms-weekly-calendar ~/.config/DankMaterialShell/plugins/weeklyCalendar
    ```
2.  Enable the plugin in DMS Settings or add it to your `plugin_settings.json`.
3.  Add the widget to your bar in `settings.json`.

## Credits & Attribution

This plugin is a substantial port and enhancement of the [Weekly Calendar](https://github.com/noctalia-dev/noctalia-plugins/tree/main/weekly-calendar) plugin by **dodaars** for Noctalia Shell. 

Key changes for DMS include:
- Complete rewrite of styling to use DMS `Theme` and `Appearance` singletons.
- Adaptation to DMS `PluginComponent` and `PluginSettings` architecture.
- Implementation of `DankPopout` integration for the detail view.
- Support for `ICalGLib 4.0` introspection.

## License

GPL-3.0
