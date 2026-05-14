#!/usr/bin/env python3
"""
create-event.py  <title> <start_ts> <end_ts> <calendar_uid>

Creates a VEVENT in the specified EDS calendar.
Prints JSON: {"success": true, "uid": "..."} or {"error": "..."}
"""
import gi
gi.require_version('EDataServer', '1.2')
gi.require_version('ECal', '2.0')
try:
    gi.require_version('ICalGLib', '3.0')
except ValueError:
    gi.require_version('ICalGLib', '4.0')

import sys, json, uuid
from datetime import datetime, timezone
from gi.repository import ECal, EDataServer, ICalGLib

if len(sys.argv) < 5:
    print(json.dumps({"error": "Usage: create-event.py <title> <start_ts> <end_ts> <calendar_uid>"}))
    sys.exit(1)

title       = sys.argv[1]
start_ts    = int(sys.argv[2])
end_ts      = int(sys.argv[3])
calendar_uid = sys.argv[4]

try:
    registry = EDataServer.SourceRegistry.new_sync(None)
    sources  = registry.list_sources(EDataServer.SOURCE_EXTENSION_CALENDAR)

    target = None
    for source in sources:
        if source.get_uid() == calendar_uid and source.get_enabled():
            target = source
            break

    if not target:
        print(json.dumps({"error": f"Calendar not found: {calendar_uid}"}))
        sys.exit(1)

    client = ECal.Client.connect_sync(target, ECal.ClientSourceType.EVENTS, 5, None)

    start_dt = datetime.fromtimestamp(start_ts)
    end_dt   = datetime.fromtimestamp(end_ts)
    now_utc  = datetime.now(timezone.utc)
    event_uid = str(uuid.uuid4())

    # Build a bare VEVENT — create_object_sync expects the component directly, not a VCALENDAR wrapper
    vevent_str = "\r\n".join([
        "BEGIN:VEVENT",
        f"UID:{event_uid}",
        f"DTSTAMP:{now_utc.strftime('%Y%m%dT%H%M%SZ')}",
        f"SUMMARY:{title}",
        f"DTSTART:{start_dt.strftime('%Y%m%dT%H%M%S')}",
        f"DTEND:{end_dt.strftime('%Y%m%dT%H%M%S')}",
        "END:VEVENT",
        "",
    ])

    comp = ICalGLib.Component.new_from_string(vevent_str)
    # Try singular API first (most common in ECal 2.0)
    try:
        success, uid = client.create_object_sync(comp, ECal.OperationFlags.NONE, None)
        if success:
            print(json.dumps({"success": True, "uid": uid or event_uid}))
        else:
            print(json.dumps({"error": "create_object_sync returned false"}))
    except Exception:
        # Fallback: plural API
        success, uids = client.create_objects_sync([comp], ECal.OperationFlags.NONE, None)
        if success:
            print(json.dumps({"success": True, "uid": uids[0] if uids else event_uid}))
        else:
            print(json.dumps({"error": "create_objects_sync returned false"}))

except Exception as e:
    print(json.dumps({"error": str(e)}))
