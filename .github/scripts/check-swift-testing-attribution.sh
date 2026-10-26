#!/usr/bin/env bash
# Fails when Swift Testing recorded an issue that no test owns.
#
# An issue recorded where Swift Testing cannot see the running test (inside
# `await context.perform { }`, or `viewContext.performAndWait { }` off the main
# actor) is printed as "✘ Test «unknown» recorded an issue". The test it came
# from passes, and xcodebuild prints ** TEST SUCCEEDED ** and exits 0, so without
# this check the failure leaves CI green. See CLAUDE.md (Testing);
# ZeezTests/SwiftTestingAttributionGuardTests.swift stops the known shapes at
# the source.
#
# Run after `xcodebuild test` succeeds:
#   check-swift-testing-attribution.sh <xcodebuild log> <result bundle>
set -euo pipefail

log=$1
bundle=$2
status=0

# Without Swift Testing's run summary the checks below would pass by finding
# nothing: a truncated log, or a release that reworded the line.
if ! grep -Eq 'Test run with [0-9]+ tests?' "$log"; then
  echo "::error::No Swift Testing run summary in $log, so issue attribution cannot be checked. If the summary line was reworded, update this script."
  exit 1
fi

if grep -F 'Test «unknown» recorded an issue' "$log"; then
  echo "::error::Swift Testing recorded the issues above against no test, and the tests that raised them passed. Assert outside Core Data closures (CLAUDE.md, Testing)."
  status=1
fi

if grep -E 'Test run with [0-9]+ tests?.* failed after' "$log"; then
  echo "::error::Swift Testing's run summary reports issues although xcodebuild succeeded."
  status=1
fi

# The result bundle files unattributed issues under a failed test of their own,
# "Issues recorded without an associated test or suite", whatever the log says.
summary=$(xcrun xcresulttool get test-results summary --path "$bundle")
result=$(printf '%s' "$summary" | python3 -c 'import json, sys; print(json.load(sys.stdin).get("result", "missing"))')
if [ "$result" != "Passed" ]; then
  echo "::error::The result bundle's test result is $result, not Passed:"
  printf '%s' "$summary" | python3 -c '
import json, sys
for failure in json.load(sys.stdin).get("testFailures", []):
    print("  %s: %s" % (failure.get("testName", "?"), failure.get("failureText", "")))'
  status=1
fi

exit $status
