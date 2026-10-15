#!/usr/bin/env python3
"""Check real current time only. Never fabricates or modifies Git timestamps."""
from datetime import datetime
from zoneinfo import ZoneInfo
import sys
now = datetime.now(ZoneInfo('America/New_York'))
allowed = now.weekday() >= 5 or (now.hour, now.minute, now.second) > (22, 0, 0)
print(f'{now.isoformat()}: commits {"allowed" if allowed else "must remain pending"}')
sys.exit(0 if allowed else 1)
