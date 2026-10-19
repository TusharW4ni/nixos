#!/usr/bin/env bash
# Self-check for the settings hub's pure functions (home/hub/lib.sh).
# Run: bash tests/hub-test.sh
set -u
# shellcheck source-path=SCRIPTDIR source=../home/hub/lib.sh
. "$(dirname "$0")/../home/hub/lib.sh"
ok()  { "$@" || { echo "FAIL: $*"; exit 1; }; }
nok() { ! "$@" || { echo "FAIL (accepted): $*"; exit 1; }; }

ok valid_seconds 30;  nok valid_seconds 29; nok valid_seconds abc; nok valid_seconds ""
ok valid_hhmm 20:30;  ok valid_hhmm 07:00;  nok valid_hhmm 25:00; nok valid_hhmm 7:00; nok valid_hhmm 20:60
ok valid_kelvin 4000; nok valid_kelvin 999; nok valid_kelvin 6501; nok valid_kelvin 4k

f=$(mktemp); trap 'rm -f "$f"' EXIT
[ "$(kv_get "$f" lock 300)" = 300 ]               || { echo "FAIL: default"; exit 1; }
kv_set "$f" lock 120; kv_set "$f" off 400; kv_set "$f" lock 150
[ "$(kv_get "$f" lock 300)" = 150 ]               || { echo "FAIL: overwrite"; exit 1; }
[ "$(kv_get "$f" off 330)" = 400 ]                || { echo "FAIL: other key kept"; exit 1; }
# shellcheck disable=SC2016 # literal $lock
[ "$(grep -c '^\$lock = ' "$f")" = 1 ]            || { echo "FAIL: duplicate keys"; exit 1; }
[ "$(kv_get /nonexistent lock 300)" = 300 ]       || { echo "FAIL: missing file"; exit 1; }

sunset_conf 1 20:30 07:00 4000 | grep -q 'temperature = 4000' || { echo "FAIL: sunset on"; exit 1; }
[ "$(sunset_conf 0 20:30 07:00 4000 | grep -c 'profile')" = 1 ] || { echo "FAIL: sunset off"; exit 1; }
[ "$(mods 65)" = "Super+Shift" ] || { echo "FAIL: mods 65 -> '$(mods 65)'"; exit 1; }
[ "$(mods 0)" = "" ]             || { echo "FAIL: mods 0"; exit 1; }
[ "$(mods 76)" = "Super+Ctrl+Alt" ] || { echo "FAIL: mods 76 -> '$(mods 76)'"; exit 1; }
echo PASS
