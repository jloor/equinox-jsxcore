#!/usr/bin/env bash
# Asserts that the Bunny Magic Containers app is pinned to a single replica in a single
# region, with a persistent volume mounted at /data.
#
#   BUNNY_API_KEY=... ./scripts/bunny-guard.sh <app-id>
#
# Why this exists rather than a line in a README:
#
# SQLite is single-writer, and Bunny gives EACH POD ITS OWN VOLUME. Their docs are
# explicit: for "databases and caches that expect a single writable disk, run with 1
# replica per volume, because running multiple replicas of a stateful service could lead
# to state inconsistency."
#
# So scaling to two replicas produces TWO SEPARATE DATABASES. Nothing errors. Nothing
# logs. Users see different data depending on which pod answers, and the bug looks like
# "records randomly disappearing". A dashboard setting that quietly corrupts the app is
# exactly the kind of thing that belongs in CI rather than in someone's memory.
#
# API surface (base https://api.bunny.net/mc, header "AccessKey"):
#   GET /apps/{id}                  application
#   GET /apps/{id}/autoscaling      min/max replicas
#   GET /apps/{id}/region-settings  region pinning
#   GET /apps/{id}/volumes          persistent volumes

set -uo pipefail

APP_ID="${1:?usage: BUNNY_API_KEY=... bunny-guard.sh <app-id>}"
API_KEY="${BUNNY_API_KEY:?BUNNY_API_KEY is required}"
BASE="https://api.bunny.net/mc"
FAILED=0

emit() {
    printf '{"id":"%s","status":"%s","detail":"%s"}\n' \
        "$1" "$2" "$(printf '%s' "$3" | tr -d '\n' | sed 's/"/\\"/g' | cut -c1-300)"
    [[ "$2" == "PASS" ]] || FAILED=1
    return 0
}

get() { curl -sS --max-time 30 -H "AccessKey: $API_KEY" -H "Accept: application/json" "$BASE/$1"; }

# Pulls the first value for any of the given keys, at any depth. Bunny's exact field
# names are not documented publicly, so this tolerates naming differences - but it
# NEVER guesses a default. A key it cannot find is reported UNKNOWN with the raw
# payload, never PASS. A check that passes because it could not read the value is worse
# than no check.
jfind() {
    python3 -c "
import sys, json
keys = [k.lower() for k in sys.argv[1:]]
try:
    doc = json.load(sys.stdin)
except Exception:
    sys.exit(2)
found = []
def walk(n):
    if isinstance(n, dict):
        for k, v in n.items():
            if k.lower() in keys and isinstance(v, (int, float, str, bool)):
                found.append(v)
            walk(v)
    elif isinstance(n, list):
        for v in n:
            walk(v)
walk(doc)
if not found:
    sys.exit(1)
print(found[0])
" "$@"
}

# ---------------------------------------------------------------- replicas

auto="$(get "apps/$APP_ID/autoscaling")"
if [[ -z "$auto" ]]; then
    emit replicas UNKNOWN "no response from /apps/$APP_ID/autoscaling"
else
    min="$(printf '%s' "$auto" | jfind minReplicas minReplicaCount min 2>/dev/null)"
    max="$(printf '%s' "$auto" | jfind maxReplicas maxReplicaCount max 2>/dev/null)"
    if [[ -z "$min" || -z "$max" ]]; then
        emit replicas UNKNOWN "could not read min/max from payload: $auto"
    elif [[ "$min" == "1" && "$max" == "1" ]]; then
        emit replicas PASS "min=1 max=1 (single writer preserved)"
    else
        emit replicas FAIL "min=$min max=$max - MUST both be 1; >1 replica means >1 SQLite database"
    fi
fi

# ---------------------------------------------------------------- regions

regions="$(get "apps/$APP_ID/region-settings")"
if [[ -z "$regions" ]]; then
    emit regions UNKNOWN "no response from /apps/$APP_ID/region-settings"
else
    count="$(printf '%s' "$regions" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
# Count enabled regions across whatever shape the payload uses.
def collect(n):
    out = []
    if isinstance(n, dict):
        for k, v in n.items():
            if isinstance(v, list) and 'region' in k.lower():
                out += v
            else:
                out += collect(v)
    elif isinstance(n, list):
        for v in n:
            out += collect(v)
    return out
items = collect(d)
if not items and isinstance(d, list):
    items = d
enabled = [
    r for r in items
    if not isinstance(r, dict) or r.get('enabled', r.get('Enabled', True))
]
print(len(enabled))
" 2>/dev/null)"
    if [[ -z "$count" ]]; then
        emit regions UNKNOWN "could not read regions from payload: $regions"
    elif [[ "$count" == "1" ]]; then
        emit regions PASS "pinned to 1 region"
    else
        emit regions FAIL "$count regions enabled - MUST be 1; each region gets its own volume"
    fi
fi

# ---------------------------------------------------------------- volume

vols="$(get "apps/$APP_ID/volumes")"
if [[ -z "$vols" ]]; then
    emit volume UNKNOWN "no response from /apps/$APP_ID/volumes"
elif printf '%s' "$vols" | grep -q '/data'; then
    emit volume PASS "persistent volume mounted at /data"
else
    emit volume FAIL "no volume mounted at /data - SQLite would live in the container layer and reset on every deploy: $vols"
fi

exit $FAILED
