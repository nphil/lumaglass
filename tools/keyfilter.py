#!/usr/bin/env python3
"""Adds or removes the LumaGlass entry in configd's com.webos.surfacemanager.keyFilters.

usage: keyfilter.py add|remove <handler> <script path>
Runs on the set (python 3.10). Called by tools/lumaglass; see keyfilter_set there.
"""
import json
import subprocess
import sys

mode, handler, path = sys.argv[1:4]
NAME = "com.webos.surfacemanager.keyFilters"


def luna(uri, payload):
    return subprocess.run(["luna-send", "-n", "1", uri, json.dumps(payload)],
                          capture_output=True, text=True).stdout


current = json.loads(luna("luna://com.webos.service.config/getConfigs", {"configNames": [NAME]}))
entries = [e for e in current["configs"][NAME] if e.get("handler") != handler]
if mode == "add":
    entries.insert(0, {"handler": handler, "file": path})
reply = luna("luna://com.webos.service.config/setConfigs", {"configs": {NAME: entries}})
sys.exit(0 if '"returnValue":true' in reply else 1)
