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

OBJECTTYPE=${OBJECTTYPE:-smoke}
INDEX_TIMEOUT=${INDEX_TIMEOUT:-180}

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
# A cheap first word from the index, before spending time on a datamodel: fylr
# seeds four users at setup - root plus system:deep_link, system:oai_pmh and
# system:deleted_user - and indexes them at startup. An index that is
# unreachable or was never created fails here with a clear error instead of
# looking like a datamodel problem three steps later.

step "the index answers"
api POST /api/v1/search -H "Content-Type: application/json" \
    -d '{"type":"user","generate_rights":false,"search":[]}'
hits=$(jqf '.count // empty')
[ -n "$hits" ] || fail "search returned no count ($CODE): $BODY"
[ "$hits" -ge 1 ] || fail "the user index is empty"
echo "found $hits seeded users: $(jqf '[.objects[]?.user.login? // empty] | join(" ")')"

# ---------------------------------------------------------------------------
# The rest is the test a person does by hand in the frontend: make an object
# type that takes file uploads, put an object in it with a file, and see the
# object come back from a search with its preview. Nothing else here makes
# postgres, the execserver and opensearch prove they work as one thing.
#
# The datamodel goes in as a schema, a maskset and a commit, which is the order
# the product's own API tests use. system_fields is left empty on purpose:
# fylr fills in the defaults, and naming one explicitly means guessing which
# modes that field allows for this table.

step "create the objecttype $OBJECTTYPE, which takes file uploads"
api GET /api/v1/schema/user/HEAD
[ "$CODE" = 200 ] || fail "cannot read the schema ($CODE): $BODY"
schema=$BODY

if jq -e --arg ot "$OBJECTTYPE" 'any(.tables[]?; .name == $ot)' <<< "$schema" >/dev/null 2>&1; then
    echo "$OBJECTTYPE is already in the datamodel, reusing it"
else
    tid=$(jq -r '.max_table_id + 1' <<< "$schema")
    c1=$(jq -r '.max_column_id + 1' <<< "$schema")
    c2=$(jq -r '.max_column_id + 2' <<< "$schema")
    sver=$(jq -r '.version + 1' <<< "$schema")

    api POST /api/v1/schema/user/HEAD -H "Content-Type: application/json" \
        -d "$(jq --arg ot "$OBJECTTYPE" --argjson tid "$tid" \
                 --argjson c1 "$c1" --argjson c2 "$c2" '
              .version = (.version + 1)
            | .based_on_version = (.version - 1)
            | .max_table_id = $tid
            | .max_column_id = $c2
            | .tables += [{
                name: $ot, table_id: $tid,
                pool_link: true, acl_table: true, has_tags: false,
                is_hierarchical: false, polyhierarchical: false,
                in_main_search: true, comment: "",
                unique_keys: [], bidirectional: [],
                columns: [
                  {kind:"column", name:"title", type:"text_oneline",
                   not_null:false, column_id:$c1, custom_settings:{}, name_localized:null},
                  {kind:"column", name:"file", type:"eas",
                   not_null:false, column_id:$c2, custom_settings:{}, name_localized:null}
                ]}]' <<< "$schema")"
    [ "$CODE" = 200 ] || fail "the schema was refused ($CODE): $BODY"

    api GET /api/v1/mask/HEAD
    [ "$CODE" = 200 ] || fail "cannot read the maskset ($CODE): $BODY"
    api POST /api/v1/mask/HEAD -H "Content-Type: application/json" \
        -d "$(jq --arg ot "$OBJECTTYPE" --argjson tid "$tid" \
                 --argjson c1 "$c1" --argjson c2 "$c2" --argjson sver "$sver" '
              .type = "user"
            | .version = ((.version // 0) + 1)
            | .based_on_schema_version = $sver
            | .max_mask_id = ((.max_mask_id // 0) + 1)
            | .masks = ((.masks // []) + [{
                name: ($ot + "__all_fields"), mask_id: .max_mask_id,
                table_id: $tid, table_name_hint: $ot, is_preferred: true,
                hide_in_detail: false, hide_in_editor: false,
                hide_in_print_dialog: false, standard_numbering: "",
                require_comment: "never", comment: "", system_fields: {},
                fields: [
                  {kind:"field", column_id:$c1, column_name_hint:"title",
                   edit:{mode:"edit"},
                   output:{detail:true, text:true, table:true,
                           standard:{format:"comma", order:1}, standard_eas:{}},
                   search:{expert:true, fulltext:true, facet:false, nested:false},
                   custom_settings:{}, inheritance:{inherit:false, show_in_detail:true}},
                  {kind:"field", column_id:$c2, column_name_hint:"file",
                   edit:{mode:"edit"},
                   output:{detail:true, text:true, table:true,
                           standard:{}, standard_eas:{order:1}},
                   search:{expert:true, fulltext:true, facet:false, nested:false},
                   custom_settings:{}, inheritance:{inherit:false, show_in_detail:true}}
                ]}])' <<< "$BODY")"
    [ "$CODE" = 200 ] || fail "the maskset was refused ($CODE): $BODY"

    api POST "/api/v1/schema/commit?confirm=yes"
    [ "$(jqf '.status // empty')" = ok ] || fail "the schema commit failed ($CODE): $BODY"
    echo "$OBJECTTYPE created with a text field and a file field"
fi

# ---------------------------------------------------------------------------

step "create an object holding file $eas_id"
api POST "/api/v1/db/$OBJECTTYPE" -H "Content-Type: application/json" \
    -d "$(jq -cn --arg ot "$OBJECTTYPE" --argjson eas "$eas_id" '
          [{ _objecttype: $ot, _mask: ($ot + "__all_fields"),
             ($ot): { _version: 1,
                      _pool: { pool: { "lookup:_id": { reference: "system:standard" } } },
                      title: "fylr-helm smoke test",
                      file: [{ _id: $eas, preferred: true }] } }]')"
object_id=$(jqf --arg ot "$OBJECTTYPE" '.[0][$ot]._id // empty')
[ -n "$object_id" ] || fail "the object was refused ($CODE): $BODY"
echo "created $OBJECTTYPE $object_id"

# ---------------------------------------------------------------------------
# The object has to come back from a search carrying the file, and the file has
# to still have the versions the execserver made. That is what the start page
# shows a person: the new object, with a preview on it.

step "the object comes back from a search, with its file (max ${INDEX_TIMEOUT}s)"
deadline=$((SECONDS + INDEX_TIMEOUT))
found=0
while [ $SECONDS -lt $deadline ]; do
    api POST /api/v1/search -H "Content-Type: application/json" \
        -d "{\"type\":\"object\",\"objecttypes\":[\"$OBJECTTYPE\"],\"generate_rights\":false,\"search\":[]}"
    found=$(jqf '.count // 0')
    [ "${found:-0}" -ge 1 ] && break
    sleep 2
done
[ "${found:-0}" -ge 1 ] || fail "$OBJECTTYPE $object_id never reached the index in ${INDEX_TIMEOUT}s ($CODE): $BODY"

indexed_file=$(jqf --arg ot "$OBJECTTYPE" '.objects[0][$ot].file[0]._id // empty')
indexed_versions=$(jqf --arg ot "$OBJECTTYPE" \
    '[.objects[0][$ot].file[0].versions // {} | keys[]] | join(" ")')
[ "$indexed_file" = "$eas_id" ] \
    || fail "the indexed object carries file '$indexed_file', expected $eas_id ($CODE): $BODY"
echo "search found $found object(s), carrying file $indexed_file with versions: $indexed_versions"

indexed_count=$(wc -w <<< "$indexed_versions")
[ "$indexed_count" -ge 2 ] \
    || fail "the indexed object shows only [$indexed_versions] - no preview to display"

printf '\nsmoke OK - fylr %s, execserver services %s, file %s produced %d versions, %s %s indexed with %d of them\n' \
    "$version" "$services_ok" "$eas_id" "$count" "$OBJECTTYPE" "$object_id" "$indexed_count"
