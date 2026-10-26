#!/usr/bin/env python3
"""Boot an iOS simulator for xcodebuild and print its UDID on stdout.

GitHub's macOS images load simulator runtimes lazily. Given a name-only destination,
xcodebuild waits about 60 s for a matching device and then exits 70 ("Unable to find a
device matching the provided destination specifier"). On 2026-10-26 that happened in 2 of
3 unit-tests runs on one runner image. The run that found a device took the first of two
matches, an iOS 26.2 simulator, under Xcode 16.4.

This waits for an iOS runtime instead, and picks one deterministically: the newest runtime
whose major version matches the selected Xcode's iOS simulator SDK (iOS 18 under Xcode
16.4), else the newest iOS runtime. It uses the named device on that runtime, creating it if
the image has none, then boots it and waits until it is ready, so xcodebuild can target it
with `-destination id=<UDID>`.

usage: boot-simulator.py [--dry-run] [device name] [iOS major version]
       (defaults: iPhone 16 Pro, the SDK's major version)
--dry-run reports the choice without creating or booting anything. Progress goes to
stderr; only the UDID goes to stdout.
"""
import json
import subprocess
import sys
import time

ATTEMPTS, PAUSE = 18, 10  # up to three minutes for a runtime to appear


def log(message):
    print(message, file=sys.stderr, flush=True)


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout


def simctl_json(*args):
    return json.loads(run("xcrun", "simctl", "list", "-j", *args))


def version(text):
    return tuple(int(part) for part in text.split(".") if part.isdigit())


def main(argv):
    dry_run = "--dry-run" in argv
    args = [arg for arg in argv if arg != "--dry-run"]
    name = args[0] if args else "iPhone 16 Pro"
    if len(args) > 1:
        major = int(args[1])
    else:
        sdk = run("xcrun", "--sdk", "iphonesimulator", "--show-sdk-version").strip()
        major = version(sdk)[0]
        log(f"Selected Xcode's iOS simulator SDK: {sdk}")

    for attempt in range(1, ATTEMPTS + 1):
        runtimes = [runtime for runtime in simctl_json("runtimes", "available")["runtimes"]
                    if runtime.get("platform", runtime["name"].split()[0]) == "iOS"]
        if runtimes:
            break
        log(f"No iOS runtime available yet (attempt {attempt}/{ATTEMPTS}); waiting {PAUSE} s")
        time.sleep(PAUSE)
    else:
        log(run("xcrun", "simctl", "list", "runtimes"))
        sys.exit("No iOS simulator runtime became available")

    runtime = max(runtimes, key=lambda r: (version(r["version"])[0] == major, version(r["version"])))
    log(f"iOS runtimes: {', '.join(r['name'] for r in runtimes)}; using {runtime['name']}")

    devices = simctl_json("devices", "available")["devices"].get(runtime["identifier"], [])
    device = next((d for d in devices if d["name"] == name), None)
    if device:
        udid = device["udid"]
        log(f"Using {name} {udid} ({device['state']})")
    else:
        device_type = next((t for t in simctl_json("devicetypes")["devicetypes"] if t["name"] == name), None)
        if device_type is None:
            sys.exit(f"No simulator device type named {name!r}")
        if dry_run:
            log(f"Would create {name} on {runtime['name']}")
            return
        udid = run("xcrun", "simctl", "create", name, device_type["identifier"], runtime["identifier"]).strip()
        log(f"Created {name} {udid} on {runtime['name']}")

    if dry_run:
        log("Dry run: not booting")
    else:
        # bootstatus -b boots the device if it is not booted and returns once it is ready.
        subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True, stdout=sys.stderr)
    print(udid)


if __name__ == "__main__":
    main(sys.argv[1:])
