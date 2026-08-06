#!/usr/bin/env bash
# Production smoke test for the built runtime image.
#
#   ./scripts/smoke-image.sh ghcr.io/jloor/equinox-jsxcore:latest
#
# scripts/verify.sh exercises the app in DEVELOPMENT. Every deploy blocker found while
# containerising was PRODUCTION-only and invisible to it:
#
#   1. the DB provider was inferred from the environment name in two files, so the
#      Identity context silently fell back to SQL Server
#   2. DbMigrationHelpers only migrates under Development or Docker, so no schema existed
#   3. Facebook/Google auth options validate lazily - the app started clean, logged
#      "Application started", then threw on every request
#
# All three produce a healthy-looking process. Only fetching real pages finds them, which
# is what this does.

set -uo pipefail

IMAGE="${1:?usage: smoke-image.sh <image>}"
# Not 8080: that port is frequently already in use, and a container that fails to bind
# leaves curl talking to whatever else is listening. That happened during development and
# returned HTTP 200 from an unrelated application.
PORT="${PORT:-18080}"
NAME="equinox-smoke-$$"
FAILED=0

DOCKER="$(command -v docker || command -v podman)"

cleanup() { $DOCKER rm -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT

emit() {
    printf '{"id":"%s","status":"%s","detail":"%s"}\n' "$1" "$2" "$3"
    [[ "$2" == "FAIL" ]] && FAILED=1
    return 0
}

$DOCKER rm -f "$NAME" >/dev/null 2>&1 || true
$DOCKER run -d --name "$NAME" -p "$PORT:8080" "$IMAGE" >/dev/null

# 127.0.0.1, not localhost. localhost resolves to ::1 first; a container binding IPv4 only
# accepts the connection at the forwarder and never answers, which reads as a hung app.
BASE="http://127.0.0.1:$PORT"

up=0
for _ in $(seq 1 90); do
    curl -sf -o /dev/null --max-time 5 "$BASE/" 2>/dev/null && { up=1; break; }
    sleep 1
done

if [[ "$up" -ne 1 ]]; then
    emit container-responds FAIL "no response on :$PORT after 90s"
    echo "--- container log ---" >&2
    $DOCKER logs "$NAME" 2>&1 | tail -30 >&2
    exit 1
fi
emit container-responds PASS "serving on :$PORT"

# The environment name is load-bearing: under Production, DbMigrationHelpers creates no
# schema at all and every request 500s.
env_line="$($DOCKER logs "$NAME" 2>&1 | grep -i 'Hosting environment' | tail -1)"
[[ "$env_line" == *Docker* ]] \
    && emit environment PASS "Docker (migrations + seeding enabled)" \
    || emit environment FAIL "expected Docker, got: ${env_line:-<none>}"

check() { # id path expected-substring
    local body code
    body="$(curl -s --max-time 20 "$BASE$2")"
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$BASE$2")"
    if [[ "$code" != "200" ]]; then
        emit "$1" FAIL "$2 -> HTTP $code"
    elif [[ -n "$3" && "$body" != *"$3"* ]]; then
        emit "$1" FAIL "$2 -> 200 but missing '$3'"
    else
        emit "$1" PASS "$2 -> 200"
    fi
}

# Assert on a marker that proves the LAYOUT and the VIEW both rendered, rather than on
# copy. An earlier version pinned the exact <title> text and broke the build the first
# time the home page was reworded - a false failure that says nothing about health.
# The nav link comes from Shared/Layout.tsx, so its presence proves the layout composed.
check home            "/"                                "/customer-management/list-all"
check customer-list   "/customer-management/list-all"    "Eduardo Pires"
check identity-login  "/Identity/Account/Login"          ""
check identity-reg    "/Identity/Account/Register"       ""

# Views must be server-rendered. Missing "use server" leaves an empty root div that looks
# fine in a browser and is blank to crawlers and no-JS clients.
#
# Fetch into a variable and assert it is non-empty FIRST. An earlier version piped curl
# straight into grep with a mistyped flag; curl exited, grep saw empty input, found no
# empty-root-div, and reported PASS. A check that passes when its own fetch fails is worse
# than no check.
home_html="$(curl -s --max-time 20 "$BASE/")"
if [[ -z "$home_html" ]]; then
    emit server-rendered FAIL "could not fetch / to inspect markup"
elif [[ "$home_html" == *'<div id="jsxcore-root"></div>'* ]]; then
    emit server-rendered FAIL "root div is empty - view rendered client-side"
elif [[ "$home_html" != *'jsxcore-root'* ]]; then
    emit server-rendered FAIL "no jsxcore-root container in markup"
else
    emit server-rendered PASS "markup present in root div"
fi

# The database has to land on the mounted path, or it vanishes on every restart.
if $DOCKER exec "$NAME" ls /data/equinox.db >/dev/null 2>&1; then
    emit sqlite-on-volume PASS "/data/equinox.db exists"
else
    emit sqlite-on-volume FAIL "no database at /data/equinox.db"
fi

# Options validated lazily mean a clean startup log proves nothing. Check after traffic.
errs="$($DOCKER logs "$NAME" 2>&1 | grep -ci 'unhandled exception')"
[[ "$errs" -eq 0 ]] \
    && emit no-unhandled-exceptions PASS "clean log after requests" \
    || emit no-unhandled-exceptions FAIL "$errs unhandled exception(s): $($DOCKER logs "$NAME" 2>&1 | grep -i -A2 'unhandled exception' | head -4 | tr '\n' ' ')"

exit $FAILED
