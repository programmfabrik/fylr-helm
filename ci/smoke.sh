#!/usr/bin/env bash
#
# Functional smoke test against a fylr installed from charts/fylr (#80603).
#
# `helm test` only wgets a port, which a fylr that cannot reach its database
# still answers. This drives the API instead, so every part the chart wires up
# has to actually work: the oauth2 client the configmap declares, the database
# secret, the S3 location pointing at minio, the execserver Service, and the
# index. Every step reports the status and body it got when it fails.
#
#   BASE            where the ingress answers, e.g. http://192.168.49.2
#   HOST            Host header to send, must match fylr.externalURL's host
#   EXPECT_VERSION  chart appVersion; asserted against the running instance
#   PRODUCE_TIMEOUT seconds to wait for the upload's versions (default 300)

set -euo pipefail
cd "$(dirname "$0")/.."

BASE=${BASE:?set BASE to where the ingress answers, e.g. http://$(minikube ip 2>/dev/null || echo 1.2.3.4)}
HOST=${HOST:-fylr.test}
LOGIN=${LOGIN:-root}
PASSWORD=${PASSWORD:-admin}
EXPECT_VERSION=${EXPECT_VERSION:-}
EXPECT_EXTERNAL_URL=${EXPECT_EXTERNAL_URL:-http://$HOST}
PRODUCE_TIMEOUT=${PRODUCE_TIMEOUT:-300}

TOKEN=""
BODY=""
CODE=""

step() { printf '\n=== %s\n' "$*"; }
fail() { printf '\nFAILED: %s\n' "$*" >&2; exit 1; }

# api METHOD PATH [curl args...] sets BODY and CODE. It never fails the script
# itself: a caller that wants to stop says so, and says what it saw.
api() {
    local method=$1 path=$2 out
    shift 2
    local auth=()
    if [ -n "$TOKEN" ]; then
        auth=(-H "Authorization: Bearer $TOKEN")
    fi
    if out=$(curl -sS --max-time 120 -w $'\n%{http_code}' \
        -H "Host: $HOST" ${auth[@]+"${auth[@]}"} \
        -X "$method" "$BASE$path" "$@" 2>&1); then
        CODE=${out##*$'\n'}
        BODY=${out%$'\n'*}
    else
        CODE=000
        BODY=$out
    fi
}

# jqf FILTER — read a value out of BODY, empty if it is not there or BODY is
# not what we expected. Callers report BODY themselves, so a parse failure
# never hides the response that caused it.
jqf() { jq -r "$@" <<< "$BODY" 2>/dev/null || true; }

# ---------------------------------------------------------------------------

step "authenticate as $LOGIN"
api POST /api/oauth2/token \
    -d "grant_type=password&username=$LOGIN&password=$PASSWORD&client_id=fylr-web-frontend"
TOKEN=$(jqf '.access_token // empty')
[ -n "$TOKEN" ] || fail "no access token ($CODE): $BODY"
echo "got a token"

# ---------------------------------------------------------------------------
# The instance answering must be the one the chart pinned, reachable under the
# URL the chart configured. A tag that silently resolved to something else, or
# an externalURL that disagrees with the ingress, both land here.

step "the running instance matches the chart"
api GET /api/v1/settings
version=$(jqf '.version // empty')
external_url=$(jqf '.external_url // empty')
[ -n "$version" ] || fail "no version in /api/v1/settings ($CODE): $BODY"
echo "version=$version external_url=$external_url"

# compared without the leading v, which Chart.yaml and /api/v1/settings both
# carry today but neither promises
if [ -n "$EXPECT_VERSION" ] && [ "${version#v}" != "${EXPECT_VERSION#v}" ]; then
    fail "chart appVersion is ${EXPECT_VERSION#v} but the instance reports ${version#v}"
fi
if [ "${external_url%/}" != "${EXPECT_EXTERNAL_URL%/}" ]; then
    fail "instance reports external_url $external_url, expected $EXPECT_EXTERNAL_URL"
fi

# ---------------------------------------------------------------------------
# The upload proves the S3 location: without a reachable minio, correct
# credentials, and a location that connected, the file never leaves pending.

step "upload ci/assets/smoke.png"
api POST /api/v1/eas/put -F "file=@ci/assets/smoke.png"
eas_id=$(jqf 'if type == "array" then .[0]._id else empty end // empty')
[ -n "$eas_id" ] || fail "no file id in the upload response ($CODE): $BODY"
echo "uploaded as file $eas_id"

# ---------------------------------------------------------------------------
# Versions are produced by the execserver, which fylr reaches through the
# Service address the configmap builds. This step is the one that fails when
# the execserver subchart and the fylr chart disagree about that address.

step "every version of the upload reaches done (max ${PRODUCE_TIMEOUT}s)"
deadline=$((SECONDS + PRODUCE_TIMEOUT))
status=""
while [ $SECONDS -lt $deadline ]; do
    api GET /api/v1/eas --get \
        --data-urlencode "ids=[$eas_id]" --data-urlencode "format=standard"
    status=$(jqf --arg id "$eas_id" '.[$id].status // empty')
    case "$status" in
        done) break ;;
        failed) fail "file $eas_id failed to produce ($CODE): $BODY" ;;
    esac
    sleep 2
done
[ "$status" = done ] || fail "file $eas_id is still '$status' after ${PRODUCE_TIMEOUT}s ($CODE): $BODY"

versions_done=$(jqf --arg id "$eas_id" \
    '[.[$id].versions // {} | to_entries[] | select(.value.status == "done") | .key] | join(" ")')
echo "versions done: $versions_done"

# "original" alone only proves the upload was stored. A second version means
# the execserver actually ran a conversion for it.
count=$(wc -w <<< "$versions_done")
[ "$count" -ge 2 ] || fail "only [$versions_done] produced - the execserver did no work"

# ---------------------------------------------------------------------------
# fylr indexes its own users at startup, so this needs no datamodel: if the
# index is unreachable or was never created, the search errors or finds nobody.

step "the index answers"
api POST /api/v1/search -H "Content-Type: application/json" \
    -d '{"type":"user","generate_rights":false,"search":[]}'
hits=$(jqf '.count // empty')
[ -n "$hits" ] || fail "search returned no count ($CODE): $BODY"
[ "$hits" -ge 1 ] || fail "the user index is empty"
echo "search found $hits user(s)"

printf '\nsmoke OK - fylr %s, file %s produced %d versions, index served %s users\n' \
    "$version" "$eas_id" "$count" "$hits"
