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
#   READY_TIMEOUT   seconds to wait for the ingress to route (default 180)
#   PRODUCE_TIMEOUT seconds to wait for the upload's versions (default 300)
#
# The execserver check needs a way to reach the execserver, which is a ClusterIP
# service the ingress does not publish. Give it either:
#
#   EXECSERVER_URL  where it answers, e.g. http://127.0.0.1:18070
#   EXECSERVER_SVC  a service for this script to port-forward to, with
#                   NAMESPACE, EXECSERVER_PORT (8070) and PF_PORT (18070)
#
# With neither set the check is skipped, which is what a release without the
# execserver subchart wants. EXPECT_SERVICES overrides the list it asserts;
# the default is what charts/execserver/values.yaml calls validationServices.

set -euo pipefail
cd "$(dirname "$0")/.."

BASE=${BASE:?set BASE to where the ingress answers, e.g. http://$(minikube ip 2>/dev/null || echo 1.2.3.4)}
HOST=${HOST:-fylr.test}
LOGIN=${LOGIN:-root}
PASSWORD=${PASSWORD:-admin}
EXPECT_VERSION=${EXPECT_VERSION:-}
EXPECT_EXTERNAL_URL=${EXPECT_EXTERNAL_URL:-http://$HOST}
READY_TIMEOUT=${READY_TIMEOUT:-180}
PRODUCE_TIMEOUT=${PRODUCE_TIMEOUT:-300}

EXECSERVER_URL=${EXECSERVER_URL:-}
EXECSERVER_SVC=${EXECSERVER_SVC:-}
EXECSERVER_PORT=${EXECSERVER_PORT:-8070}
PF_PORT=${PF_PORT:-18070}
NAMESPACE=${NAMESPACE:-}
KUBE_CACHE_DIR=${KUBE_CACHE_DIR:-}
EXPECT_SERVICES=${EXPECT_SERVICES:-$(awk -F'"' '/^  validationServices:/ {print $2}' \
    charts/execserver/values.yaml 2>/dev/null || true)}

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
# A ready fylr pod is not yet a routable one: the ingress controller picks up
# the new endpoint on its own schedule, and a 502 from nginx in the first
# assertion reads like fylr rejecting the login. Wait for the ingress to reach
# fylr at all before testing what fylr does.

step "the ingress routes to fylr (max ${READY_TIMEOUT}s)"
deadline=$((SECONDS + READY_TIMEOUT))
while [ $SECONDS -lt $deadline ]; do
    api GET /api/v1/settings
    case "$CODE" in
        000|502|503|504) sleep 3 ;;
        *) break ;;
    esac
done
case "$CODE" in
    000|502|503|504) fail "the ingress still answers $CODE after ${READY_TIMEOUT}s: $BODY" ;;
esac
echo "ingress answers $CODE"

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
# Every service the chart's own execserver test names has to be one the
# execserver actually offers. That test cannot show this. It reads the answer
# to /job/<service> with jq, but an execserver that does not have the service
# replies 404 with the plain text `Unknown service "name"` - jq fails on it,
# the error message comes out empty, and the service is reported as passing.
#
# Two ways to ask, because the endpoint changed under us: from 6.35 the broker
# rewrite dropped /job/<service> and added /broker/status, which returns the
# want-book as JSON. Ask that first and fall back to probing each service.

es_get() {
    local out
    if out=$(curl -sS --max-time 30 -w $'\n%{http_code}' "$EXECSERVER_URL$1" 2>&1); then
        ES_CODE=${out##*$'\n'}
        ES_BODY=${out%$'\n'*}
    else
        ES_CODE=000
        ES_BODY=$out
    fi
}

step "the execserver offers the services the chart names"
services_ok=skipped
if [ -z "$EXECSERVER_URL" ] && [ -z "$EXECSERVER_SVC" ]; then
    echo "neither EXECSERVER_URL nor EXECSERVER_SVC set - skipped"
else
    [ -n "$EXPECT_SERVICES" ] || fail "EXPECT_SERVICES is empty and charts/execserver/values.yaml did not yield one"
    wanted=${EXPECT_SERVICES//,/ }

    if [ -z "$EXECSERVER_URL" ]; then
        command -v kubectl >/dev/null || fail "EXECSERVER_SVC is set but kubectl is not installed"
        kc=(kubectl)
        [ -n "$NAMESPACE" ] && kc+=(-n "$NAMESPACE")
        [ -n "$KUBE_CACHE_DIR" ] && kc+=(--cache-dir "$KUBE_CACHE_DIR")
        "${kc[@]}" port-forward "$EXECSERVER_SVC" "$PF_PORT:$EXECSERVER_PORT" >/dev/null 2>&1 &
        pf_pid=$!
        trap 'kill $pf_pid 2>/dev/null || true' EXIT
        EXECSERVER_URL=http://127.0.0.1:$PF_PORT
        deadline=$((SECONDS + 60))
        until curl -sf --max-time 3 "$EXECSERVER_URL/healthz" >/dev/null 2>&1; do
            kill -0 $pf_pid 2>/dev/null || fail "port-forward to $EXECSERVER_SVC died"
            [ $SECONDS -lt $deadline ] || fail "port-forward to $EXECSERVER_SVC never answered on $PF_PORT"
            sleep 1
        done
    fi

    echo "asking $EXECSERVER_URL for: $wanted"
    missing=""
    es_get /broker/status
    offered=$(jq -r '.service_stats // {} | keys | join(" ")' <<< "$ES_BODY" 2>/dev/null || true)

    if [ -n "$offered" ]; then
        for want in $wanted; do
            grep -qw -- "$want" <<< "$offered" || missing="$missing $want"
        done
        echo "the want-book lists: $offered"
    else
        # No want-book, so this is a 6.34 execserver: ask it for a job of each
        # service and read the refusal. "Unknown service" is the one that means
        # the service is not configured; anything else means it is.
        for want in $wanted; do
            es_get "/job/$want"
            case "$ES_BODY" in
                *"Unknown service"*)   missing="$missing $want" ;;
                *"404 page not found"*) fail "the execserver serves neither /broker/status nor /job/<service> ($ES_CODE): $ES_BODY" ;;
            esac
        done
        echo "probed /job/<service>, this execserver has no want-book endpoint"
    fi

    [ -z "$missing" ] || fail "the execserver does not offer:$missing"
    services_ok=$(wc -w <<< "$wanted")
    echo "all $services_ok present"
fi

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

printf '\nsmoke OK - fylr %s, execserver services %s, file %s produced %d versions, index served %s users\n' \
    "$version" "$services_ok" "$eas_id" "$count" "$hits"
