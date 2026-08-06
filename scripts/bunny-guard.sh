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

# ---------------------------------------------------------------- regions + volume
#
# Both come from GET /apps/{id}, whose real shape is:
#
#   regionSettings: { allowedRegionIds: ["ASB"], requiredRegionIds: ["ASB"],
#                     maxAllowedRegions: 1, provisioningType: "static" }
#   volumes:        [ { name: "equinox-data", size: 1 } ]
#   containerTemplates: [ { volumeMounts: [ { name: ..., mountPath: "/data" } ] } ]
#
# An earlier version of this script guessed at these. It walked the payload for any list
# whose key contained "region" and summed them, so allowedRegionIds + requiredRegionIds
# (both ["ASB"]) counted as 2 regions. And it looked for the mount path in
# /apps/{id}/volumes, which reports name/size/usage but NOT mountPath. Both produced
# false FAILs against a correctly configured app.
#
# Failing safe is necessary but not sufficient: a guard that cries wolf gets ignored, and
# an ignored guard protects nothing.

app="$(get "apps/$APP_ID")"

if [[ -z "$app" ]]; then
    emit regions UNKNOWN "no response from /apps/$APP_ID"
    emit volume  UNKNOWN "no response from /apps/$APP_ID"
else
    printf '%s' "$app" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print('regions|UNKNOWN|payload was not JSON')
    print('volume|UNKNOWN|payload was not JSON')
    raise SystemExit(0)

rs = d.get('regionSettings') or {}
allowed  = rs.get('allowedRegionIds')  or []
required = rs.get('requiredRegionIds') or []
cap      = rs.get('maxAllowedRegions')

# The set of DISTINCT regions is what matters; allowed and required overlap by design.
distinct = sorted(set(allowed) | set(required))

if not distinct and cap is None:
    print('regions|UNKNOWN|no regionSettings in payload')
elif len(distinct) != 1:
    print('regions|FAIL|%d distinct regions %s - MUST be 1; each region gets its own volume'
          % (len(distinct), distinct))
elif cap not in (None, 1):
    print('regions|FAIL|pinned to %s but maxAllowedRegions=%s allows scaling out' % (distinct[0], cap))
else:
    print('regions|PASS|pinned to %s (maxAllowedRegions=%s)' % (distinct[0], cap))

# mountPath lives on the container template; the volume itself is declared app-level.
declared = {v.get('name') for v in (d.get('volumes') or []) if isinstance(v, dict)}
mounts = []
for ct in d.get('containerTemplates') or []:
    for m in ct.get('volumeMounts') or []:
        mounts.append((m.get('name'), m.get('mountPath')))

at_data = [n for n, p in mounts if p == '/data']

if not d.get('containerTemplates'):
    print('volume|UNKNOWN|no containerTemplates in payload')
elif not at_data:
    print('volume|FAIL|nothing mounted at /data (mounts=%s) - SQLite would live in the '
          'container layer and reset on every deploy' % (mounts or 'none'))
elif not declared:
    print('volume|FAIL|%s mounted at /data but no persistent volume declared' % at_data[0])
elif at_data[0] not in declared:
    print('volume|FAIL|mount references %r but declared volumes are %s' % (at_data[0], sorted(declared)))
else:
    print('volume|PASS|persistent volume %r mounted at /data' % at_data[0])
" 2>/dev/null | while IFS='|' read -r id status detail; do
        emit "$id" "$status" "$detail"
    done
    # The while loop runs in a subshell, so re-derive the failure state here.
    if printf '%s' "$app" | grep -q '"regionSettings"'; then
        distinct="$(printf '%s' "$app" | python3 -c "
import sys, json
d = json.load(sys.stdin); rs = d.get('regionSettings') or {}
print(len(set(rs.get('allowedRegionIds') or []) | set(rs.get('requiredRegionIds') or [])))
" 2>/dev/null)"
        [[ "$distinct" == "1" ]] || FAILED=1
    fi
    printf '%s' "$app" | grep -q '"mountPath": *"/data"' || FAILED=1
fi

exit $FAILED
