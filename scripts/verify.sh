#!/usr/bin/env bash
# Verification oracle for the Equinox -> JsxCore migration.
#
# Emits one JSON object per criterion on stdout. Exits non-zero if any FAIL.
# Designed to run INSIDE the .NET 9 container (needs dotnet + curl).
#
#   ./scripts/verify.sh            # build + runtime + CRUD
#   ./scripts/verify.sh --static   # skip build/run, static checks only (fast)
#
# Why this exists: six of the original spec's nine success criteria had no
# machine-checkable form. Without an oracle an agent grades its own homework.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB="$ROOT/src/Equinox.UI.Web"
VIEWS="$WEB/Views"
PORT="${PORT:-5000}"
BASE="http://localhost:$PORT"

# Unmodified Equinox emitted 16 NU1903 warnings: 8 distinct high-severity
# advisories against System.Security.Cryptography.Xml 9.0.3, each reported twice.
# Patched in D11 by bumping the crypto chain to 9.0.18, so the spec's original
# "0 warnings" criterion is now genuinely reachable and is asserted as written.
BASELINE_WARNINGS="${BASELINE_WARNINGS:-0}"

FAILED=0
STATIC_ONLY=0
[[ "${1:-}" == "--static" ]] && STATIC_ONLY=1

emit() { # id status detail
    printf '{"id":"%s","status":"%s","detail":"%s"}\n' \
        "$1" "$2" "$(printf '%s' "$3" | tr -d '\n' | sed 's/"/\\"/g')"
    [[ "$2" == "FAIL" ]] && FAILED=1
    return 0
}

token_from() { # file -> antiforgery token
    grep -oE '<input[^>]*name="__RequestVerificationToken"[^>]*>' "$1" \
        | head -1 | grep -oP 'value="\K[^"]+'
}

code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

# ---------------------------------------------------------------- static checks

# D2/D12: Razor and JsxCore coexist. The ASP.NET Identity Razor Pages stay - they are
# required to log in, and logging in is required to exercise Customer CRUD, which is
# [Authorize]. Those pages pull three Razor files with them, so the allowlist is exact
# rather than a loosened "ignore Shared/":
#
#   _Layout.cshtml               <- Areas/Identity/Pages/_ViewStart.cshtml names it by path
#   _LoginPartial.cshtml         <- <partial name="_LoginPartial" /> inside _Layout.cshtml
#   _ValidationScriptsPartial    <- <partial ... /> in Login.cshtml and Register.cshtml
#   _ViewImports / _ViewStart    <- Razor infrastructure
#
# Anything else appearing under Views/ is unconverted work and must fail.
RAZOR_ALLOWED='_ViewImports.cshtml|_ViewStart.cshtml|_Layout.cshtml|_LoginPartial.cshtml|_ValidationScriptsPartial.cshtml'

leftover="$(find "$VIEWS" -name '*.cshtml' 2>/dev/null | grep -cvE "$RAZOR_ALLOWED")"
if [[ "$leftover" -eq 0 ]]; then
    emit no-cshtml-in-views PASS "only Identity-required Razor files remain under Views/"
else
    emit no-cshtml-in-views FAIL "$leftover unconverted .cshtml: $(find "$VIEWS" -name '*.cshtml' | grep -vE "$RAZOR_ALLOWED" | head -5 | tr '\n' ' ')"
fi

# D8: every converted view must declare "use server" as its FIRST statement.
# Forgetting it does not error - the page renders blank to crawlers and no-JS
# clients while looking correct in a browser. Highest-risk silent failure found.
#
# Applies to VIEWS only, not shared components. JsxCore consults the directive on
# the view the endpoint named and nothing else: "A directive at the top of
# Shared/Card.tsx says nothing about the pages that import it." The docs give the
# distinction - "Only the view needs a default export" - so that is the test.
missing=""
count=0
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    grep -qE '^\s*export\s+default' "$f" || continue   # component, not a view
    count=$((count + 1))
    first="$(grep -vE '^\s*(//|/\*|\*|$)' "$f" | head -1)"
    [[ "$first" =~ ^\"use\ server\"\;?$|^\'use\ server\'\;?$ ]] || missing="$missing ${f#$VIEWS/}"
done < <(find "$VIEWS" -name '*.tsx' 2>/dev/null)

if [[ "$count" -eq 0 ]]; then
    emit tsx-use-server SKIP "no .tsx views yet"
elif [[ -z "$missing" ]]; then
    emit tsx-use-server PASS "all $count .tsx views declare \"use server\""
else
    emit tsx-use-server FAIL "missing \"use server\":$missing"
fi

# Generated model types must be committed and must cover CustomerViewModel.
#
# Type generation runs twice: at build (with DEFAULT config, scanning only the web
# assembly) and at application startup (with the configured AutoExport). CustomerViewModel
# lives in Equinox.Application, so the build-time pass never sees it - the committed
# runtime output under Views/generated is what the views actually compile against.
#
# If that file goes stale or missing, the views silently lose their types rather than
# failing, so this asserts it exists and contains the model.
GENERATED="$VIEWS/generated/types.d.ts"
if [[ ! -f "$GENERATED" ]]; then
    emit generated-types FAIL "no committed types at Views/generated/types.d.ts - views would lose C# type safety"
elif ! grep -q "interface CustomerViewModel" "$GENERATED"; then
    emit generated-types FAIL "committed types are missing CustomerViewModel: $(grep -oE 'interface [A-Za-z]+' "$GENERATED" | tr '\n' ' ')"
else
    emit generated-types PASS "CustomerViewModel generated from C# and committed"
fi

# TypeScript errors must be fatal, or "the model and the view cannot drift" is advisory.
if grep -q "<JsxCoreTypeChecking>error</JsxCoreTypeChecking>" "$WEB/Equinox.UI.Web.csproj"; then
    emit typecheck-fatal PASS "JsxCoreTypeChecking=error - C#/TSX drift fails the build"
else
    emit typecheck-fatal FAIL "JsxCoreTypeChecking is not 'error'; TS2339 would only warn"
fi

# Every Razor view that is NOT deliberately retained should have a .tsx counterpart.
for v in $(find "$VIEWS" -name '*.cshtml' 2>/dev/null | grep -vE "$RAZOR_ALLOWED"); do
    [[ -f "${v%.cshtml}.tsx" ]] || emit tsx-parity FAIL "no .tsx for ${v#$VIEWS/}"
done

[[ "$STATIC_ONLY" -eq 1 ]] && { exit $FAILED; }

# ---------------------------------------------------------------------- build

BUILD_LOG="$(mktemp)"
if dotnet build "$ROOT/Equinox.sln" > "$BUILD_LOG" 2>&1; then
    errs=$(grep -cP ': error ' "$BUILD_LOG" || true)
    emit build PASS "0 errors"
else
    emit build FAIL "$(grep -P ': error ' "$BUILD_LOG" | head -3 | tr '\n' ';')"
fi

warns="$(grep -oP '^\s+\K\d+(?= Warning\(s\))' "$BUILD_LOG" | tail -1 || echo 0)"
warns="${warns:-0}"
if [[ "$warns" -le "$BASELINE_WARNINGS" ]]; then
    emit build-no-new-warnings PASS "$warns warnings (baseline $BASELINE_WARNINGS)"
else
    emit build-no-new-warnings FAIL "$warns warnings > baseline $BASELINE_WARNINGS: $(grep -oP 'warning \K[A-Z]+[0-9]+' "$BUILD_LOG" | sort -u | grep -v NU1903 | tr '\n' ' ')"
fi

# JsxCore must source its own toolchain. If npm is on PATH the claim is untestable.
if command -v npm >/dev/null 2>&1; then
    emit no-node-toolchain FAIL "npm present on PATH - 'no Node required' cannot be verified here"
else
    emit no-node-toolchain PASS "built with no node/npm on PATH"
fi

# ---------------------------------------------------------------------- runtime

cd "$WEB" || exit 1
rm -f EquinoxProject.db*                      # deterministic: fresh seeded DB each run
ASPNETCORE_ENVIRONMENT=Development dotnet run --no-build --urls "http://0.0.0.0:$PORT" \
    > /tmp/verify-app.log 2>&1 &
APP_PID=$!
trap 'kill $APP_PID 2>/dev/null' EXIT

up=0
for _ in $(seq 1 60); do
    curl -sf -o /dev/null "$BASE/" 2>/dev/null && { up=1; break; }
    sleep 1
done
[[ "$up" -eq 1 ]] && emit app-starts PASS "responding on :$PORT" \
                  || { emit app-starts FAIL "$(tail -3 /tmp/verify-app.log | tr '\n' ';')"; exit 1; }

# Real routes are /customer-management/*, NOT /Customer/* - the controller uses
# explicit attribute routes. A script written from the spec would 404 here.
[[ "$(code "$BASE/")" == "200" ]] \
    && emit route-home PASS "GET / -> 200" || emit route-home FAIL "GET / -> $(code "$BASE/")"

[[ "$(code "$BASE/customer-management/list-all")" == "200" ]] \
    && emit route-list PASS "list-all -> 200" \
    || emit route-list FAIL "list-all -> $(code "$BASE/customer-management/list-all")"

# The customer list runs in RenderMode.ServerAndClient: the SAME component renders on the
# server for first paint and then hydrates in the browser for the history modal.
#
# Both halves are asserted because either can be lost silently. Drop the hydration and the
# modal stops opening while the page still looks right. Drop the server pass and the page
# looks right in a browser and is empty to crawlers and no-JS clients. Neither errors.
list_html="$(curl -s --max-time 20 "$BASE/customer-management/list-all")"
if [[ -z "$list_html" ]]; then
    emit hydration FAIL "could not fetch the customer list"
else
    server_rendered=0; hydrating=0
    [[ "$list_html" == *"<td>Eduardo Pires</td>"* ]] && server_rendered=1
    [[ "$list_html" == *'"hydrate":true'* ]] && hydrating=1

    if [[ "$server_rendered" -eq 1 && "$hydrating" -eq 1 ]]; then
        emit hydration PASS "server-rendered rows AND hydrate:true - one component, both passes"
    elif [[ "$hydrating" -eq 1 ]]; then
        emit hydration FAIL "hydrating but no server-rendered rows - blank to crawlers and no-JS clients"
    elif [[ "$server_rendered" -eq 1 ]]; then
        emit hydration FAIL "server-rendered but not hydrating - the history modal will not open"
    else
        emit hydration FAIL "neither server-rendered rows nor hydration markers present"
    fi

    # Layout reads .NET globals, which throw on the client pass. The server writes its
    # answers into data attributes so the client can reproduce identical markup; without
    # them a signed-in user's nav flips to "Register / Login" after hydration.
    [[ "$list_html" == *"data-signed-in="* ]] \
        && emit hydration-safe-globals PASS "nav state bridged to the client pass" \
        || emit hydration-safe-globals FAIL "no data-signed-in marker - nav will mismatch on hydration"
fi

# Create/Edit/Delete are [Authorize]; only Index/Details/History are [AllowAnonymous].
anon="$(code "$BASE/customer-management/register-new")"
[[ "$anon" == "302" ]] \
    && emit auth-enforced PASS "anonymous create -> 302 to login" \
    || emit auth-enforced FAIL "anonymous create -> $anon (expected 302)"

# ------------------------------------------------------------- authed CRUD flow

CJ="$(mktemp)"
EMAIL="verify-$$@example.com"
PASS_W='Test@12345'

curl -s -c "$CJ" "$BASE/Identity/Account/Register" > /tmp/reg.html
RT="$(token_from /tmp/reg.html)"
curl -s -b "$CJ" -c "$CJ" -o /dev/null -X POST "$BASE/Identity/Account/Register" \
    --data-urlencode "__RequestVerificationToken=$RT" \
    --data-urlencode "Input.Email=$EMAIL" \
    --data-urlencode "Input.Password=$PASS_W" \
    --data-urlencode "Input.ConfirmPassword=$PASS_W"

# Registration grants "Customers/Write" only (Register.cshtml.cs), so a fresh
# account can Create/Read/Update but NOT Delete - Delete needs "Customers/Remove",
# which only the seeded admin has. Grant it to our throwaway user as a test
# fixture. This touches test DATA only; the authorization code path is untouched.
if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 EquinoxProject.db \
        "INSERT INTO AspNetUserClaims (UserId, ClaimType, ClaimValue)
         SELECT Id, 'Customers', 'Remove' FROM AspNetUsers WHERE Email = '$EMAIL';" 2>/dev/null \
        && emit fixture-claim PASS "granted Customers/Remove to $EMAIL" \
        || emit fixture-claim FAIL "could not grant Remove claim"
else
    emit fixture-claim SKIP "sqlite3 unavailable - delete will fail on claims"
fi

# Claims live in the auth cookie, so re-login to pick up the new claim.
rm -f "$CJ"; CJ="$(mktemp)"
curl -s -c "$CJ" "$BASE/Identity/Account/Login" > /tmp/login.html
LT="$(token_from /tmp/login.html)"
curl -s -b "$CJ" -c "$CJ" -o /dev/null -X POST "$BASE/Identity/Account/Login" \
    --data-urlencode "__RequestVerificationToken=$LT" \
    --data-urlencode "Input.Email=$EMAIL" \
    --data-urlencode "Input.Password=$PASS_W" \
    --data-urlencode "Input.RememberMe=false"

authed="$(code -b "$CJ" "$BASE/customer-management/register-new")"
if [[ "$authed" != "200" ]]; then
    emit crud-auth FAIL "could not authenticate; create page -> $authed"
    exit 1
fi
emit crud-auth PASS "registered + logged in as $EMAIL"

# CREATE
curl -s -b "$CJ" -c "$CJ" "$BASE/customer-management/register-new" > /tmp/create.html
CT="$(token_from /tmp/create.html)"
NAME="Verify Bot $$"
VEMAIL="bot-$$@example.com"
curl -s -b "$CJ" -c "$CJ" -o /dev/null -X POST "$BASE/customer-management/register-new" \
    --data-urlencode "__RequestVerificationToken=$CT" \
    --data-urlencode "Name=$NAME" \
    --data-urlencode "Email=$VEMAIL" \
    --data-urlencode "BirthDate=1990-01-01"

curl -s -b "$CJ" "$BASE/customer-management/list-all" > /tmp/list.html
if grep -q "$VEMAIL" /tmp/list.html; then
    emit crud-create PASS "customer $VEMAIL appears in list"
else
    emit crud-create FAIL "customer $VEMAIL not found after POST"
fi

# Grab the id for read/update/delete
CID="$(grep -oP 'customer-details/\K[0-9a-f-]{36}' /tmp/list.html | tail -1)"
if [[ -z "$CID" ]]; then
    emit crud-read FAIL "no customer id found in list markup"
else
    [[ "$(code -b "$CJ" "$BASE/customer-management/customer-details/$CID")" == "200" ]] \
        && emit crud-read PASS "details/$CID -> 200" \
        || emit crud-read FAIL "details/$CID -> $(code -b "$CJ" "$BASE/customer-management/customer-details/$CID")"

    # UPDATE
    curl -s -b "$CJ" -c "$CJ" "$BASE/customer-management/edit-customer/$CID" > /tmp/edit.html
    ET="$(token_from /tmp/edit.html)"
    NEWNAME="Verified Bot $$"
    curl -s -b "$CJ" -c "$CJ" -o /dev/null -X POST "$BASE/customer-management/edit-customer/$CID" \
        --data-urlencode "__RequestVerificationToken=$ET" \
        --data-urlencode "Id=$CID" \
        --data-urlencode "Name=$NEWNAME" \
        --data-urlencode "Email=$VEMAIL" \
        --data-urlencode "BirthDate=1990-01-01"
    curl -s -b "$CJ" "$BASE/customer-management/list-all" > /tmp/list2.html
    grep -q "$NEWNAME" /tmp/list2.html \
        && emit crud-update PASS "name updated to '$NEWNAME'" \
        || emit crud-update FAIL "updated name not present after POST"

    # DELETE
    curl -s -b "$CJ" -c "$CJ" "$BASE/customer-management/remove-customer/$CID" > /tmp/del.html
    DT="$(token_from /tmp/del.html)"
    curl -s -b "$CJ" -c "$CJ" -o /dev/null -X POST "$BASE/customer-management/remove-customer/$CID" \
        --data-urlencode "__RequestVerificationToken=$DT" \
        --data-urlencode "id=$CID"
    curl -s -b "$CJ" "$BASE/customer-management/list-all" > /tmp/list3.html
    grep -q "$VEMAIL" /tmp/list3.html \
        && emit crud-delete FAIL "customer still present after delete" \
        || emit crud-delete PASS "customer removed"
fi

exit $FAILED
