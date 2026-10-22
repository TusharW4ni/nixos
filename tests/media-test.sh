#!/usr/bin/env bash
# Self-check for home/scripts/media.sh with stub playerctl/notify-send.
# Run: bash tests/media-test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin"
cat > "$t/bin/playerctl" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *playerName*) echo "chromium  playing" ;;
  *title*) echo "Tom & Jerry <i>live</i>" ;;
  *artist*) echo "A & B" ;;
  *) exit 0 ;;
esac
STUB
cat > "$t/bin/notify-send" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$OUT"
[ "${FAIL:-0}" = 1 ] && exit 1
echo 42
STUB
chmod +x "$t/bin/"*
run() { PATH="$t/bin:$PATH" XDG_RUNTIME_DIR="$t" OUT="$t/args" bash "$here/../home/scripts/media.sh" play-pause; }
fail() { echo "FAIL: $*"; exit 1; }

run
grep -qF 'Tom &amp; Jerry &lt;i&gt;live&lt;/i&gt;' "$t/args" || fail "title not markup-escaped: $(cat "$t/args")"
grep -qF 'A &amp; B' "$t/args" || fail "artist not markup-escaped"
[ "$(cat "$t/media-notify-id")" = 42 ] || fail "id not saved"

FAIL=1 run
[ "$(cat "$t/media-notify-id")" = 42 ] || fail "failed notify clobbered the saved id"

: > "$t/media-notify-id"
run
grep -qx -- '-r' "$t/args" && [ "$(grep -A1 -x -- '-r' "$t/args" | tail -1)" = 0 ] || fail "empty id file not treated as 0"
echo PASS
