#!/usr/bin/env bash
#
# Functional smoke test against a fylr installed from charts/fylr (#80603).
#
# `helm test` only wgets a port, which a fylr that cannot reach its database
# still answers. This drives the API instead, so every part the chart wires up
# has to actually work: the oauth2 client the configmap declares, the database
# secret, the S3 location pointing at minio, the execserver Service, and the
# index. Each step fails loudly with the response that broke it.
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

step() { printf '\n=== %s\n' "$*"; }
fail() { printf '\nFAILED: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------

step "authenticate as $LOGIN"
token_response=$(curl -sS --max-time 30 -H "Host: $HOST" \
    -X POST "$BASE/api/oauth2/token" \
    -d "grant_type=password&username=$LOGIN&password=$PASSWORD&client_id=fylr-web-frontend")
TOKEN=$(jq -r '.access_token // empty' <<< "$token_response")
[ -n "$TOKEN" ] || fail "no access token: $token_response"
AUTH=(-H "Authorization: Bearer $TOKEN")
echo "got a token"

# ---------------------------------------------------------------------------
# The instance answering must be the one the chart pinned, reachable under the
# URL the chart configured. A tag that silently resolved to something else, or
# an externalURL that disagrees with the ingress, both land here.

step "the running instance matches the chart"
settings=$(curl -sS --max-time 30 -H "Host: $HOST" "${AUTH[@]}" "$BASE/api/v1/settings")
version=$(jq -r '.version // empty' <<< "$settings")
external_url=$(jq -r '.external_url // empty' <<< "$settings")
[ -n "$version" ] || fail "no version in /api/v1/settings: $settings"
echo "version=$version external_url=$external_url"

if [ -n "$EXPECT_VERSION" ] && [ "$version" != "${EXPECT_VERSION#v}" ]; then
    fail "chart appVersion is $EXPECT_VERSION but the instance reports $version"
fi
if [ "${external_url%/}" != "${EXPECT_EXTERNAL_URL%/}" ]; then
    fail "instance reports external_url $external_url, expected $EXPECT_EXTERNAL_URL"
fi

# ---------------------------------------------------------------------------
# The upload proves the S3 location: without a reachable minio and correct
# credentials the file never leaves pending.

step "upload ci/assets/smoke.png"
upload=$(curl -sS --max-time 120 -H "Host: $HOST" "${AUTH[@]}" \
    -X POST "$BASE/api/v1/eas/put" -F "file=@ci/assets/smoke.png")
eas_id=$(jq -r '.[0]._id // empty' <<< "$upload")
[ -n "$eas_id" ] || fail "no file id in the upload response: $upload"
echo "uploaded as file $eas_id"

# ---------------------------------------------------------------------------
# Versions are produced by the execserver, which fylr reaches through the
# Service address the configmap builds. This step is the one that fails when
# the execserver subchart and the fylr chart disagree about that address.

step "every version of the upload reaches done (max ${PRODUCE_TIMEOUT}s)"
deadline=$((SECONDS + PRODUCE_TIMEOUT))
status=""
while [ $SECONDS -lt $deadline ]; do
    file=$(curl -sS --max-time 30 -H "Host: $HOST" "${AUTH[@]}" --get "$BASE/api/v1/eas" \
        --data-urlencode "ids=[$eas_id]" --data-urlencode "format=standard")
    status=$(jq -r --arg id "$eas_id" '.[$id].status // empty' <<< "$file")
    case "$status" in
        done) break ;;
        failed) fail "file $eas_id failed to produce: $file" ;;
    esac
    sleep 2
done
[ "$status" = done ] || fail "file $eas_id is still '$status' after ${PRODUCE_TIMEOUT}s"

versions_done=$(jq -r --arg id "$eas_id" \
    '[.[$id].versions // {} | to_entries[] | select(.value.status == "done") | .key] | join(" ")' <<< "$file")
echo "versions done: $versions_done"

# "original" alone only proves the upload was stored. A second version means
# the execserver actually ran a conversion for it.
count=$(wc -w <<< "$versions_done")
[ "$count" -ge 2 ] || fail "only [$versions_done] produced — the execserver did no work"

# ---------------------------------------------------------------------------
# fylr indexes its own users at startup, so this needs no datamodel: if the
# index is unreachable or was never created, the search errors or finds nobody.

step "the index answers"
search=$(curl -sS --max-time 60 -H "Host: $HOST" "${AUTH[@]}" -H "Content-Type: application/json" \
    -X POST "$BASE/api/v1/search" \
    -d '{"type":"user","generate_rights":false,"search":[]}')
hits=$(jq -r '.count // empty' <<< "$search")
[ -n "$hits" ] || fail "search returned no count: $search"
[ "$hits" -ge 1 ] || fail "the user index is empty"
echo "search found $hits user(s)"

printf '\nsmoke OK — fylr %s, file %s produced %d versions, index served %s users\n' \
    "$version" "$eas_id" "$count" "$hits"
