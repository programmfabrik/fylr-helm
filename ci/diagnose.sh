#!/bin/bash
# Print why an install or a test failed, from inside the cluster.
#
# helm only ever reports that it stopped waiting - "context deadline exceeded",
# "timed out waiting for the condition" - and never what it was waiting for.
# The answer is always in the cluster: an image that will not pull, a container
# that crashes on start, a probe that never passes, a hook job that fails. This
# fishes those out and prints them, so a failed run says what went wrong
# instead of only that it went wrong.
#
#   NAMESPACE=fylr-ci ./ci/diagnose.sh
#
# Run it while the cluster is still up - the callers do this before tearing it
# down. Set KUBE_CACHE_DIR to keep kubectl's discovery cache out of $HOME.
# It never fails: diagnostics must not turn one failure into two.

NAMESPACE=${NAMESPACE:-fylr-ci}
TAIL_LINES=${TAIL_LINES:-40}

kc=(kubectl)
[ -n "$KUBE_CACHE_DIR" ] && kc+=(--cache-dir "$KUBE_CACHE_DIR")
kc+=(-n "$NAMESPACE")

hdr(){ printf '\n----- %s\n' "$*"; }

if ! "${kc[@]}" get ns >/dev/null 2>&1; then
    echo "no cluster to ask - nothing to diagnose"
    exit 0
fi

hdr "pods"
"${kc[@]}" get pods -o wide 2>&1

# The single most useful line there is: kubelet's own reason and message for
# every container that is not up, init containers included. "ImagePullBackOff /
# unauthorized: access to the requested resource is not authorized" is a
# diagnosis; "context deadline exceeded" is not.
hdr "containers that are not ready, and what the kubelet says about them"
"${kc[@]}" get pods -o json 2>/dev/null | jq -r '
    .items[]
    | .metadata.name as $pod
    | [ ((.status.initContainerStatuses // []) | map(. + {kind: "init"})),
        ((.status.containerStatuses     // []) | map(. + {kind: "container"})) ]
    | flatten | .[]
    | select(.ready != true)
    | (.state | to_entries[0]) as $s
    | "\($pod)  [\(.kind) \(.name)]  restarts=\(.restartCount)\n    \($s.key): \($s.value.reason // "-")\n    \($s.value.message // "(no message)")"
' 2>/dev/null || echo "(could not read pod status)"

# A pod that was never scheduled has no container statuses at all, so the
# section above cannot see it. Its reason sits in the conditions instead, and
# on a single-node cluster it is usually "Insufficient memory" or "Insufficient
# cpu" - a failure that otherwise looks exactly like a slow install.
hdr "pods that are not scheduled or not running, and why"
"${kc[@]}" get pods -o json 2>/dev/null | jq -r '
    .items[]
    | select(.status.phase != "Running" and .status.phase != "Succeeded")
    | .metadata.name as $pod
    | "\($pod)  phase=\(.status.phase)"
      + ( [ (.status.conditions // [])[]
            | select(.status != "True")
            | "\n    \(.type): \(.reason // "-") \(.message // "")" ] | join("") )
' 2>/dev/null | grep . || echo "(every pod is Running or Succeeded)"

hdr "jobs"
"${kc[@]}" get jobs 2>&1 | grep -v '^No resources' || echo "(none)"

# A hook job that fails takes the whole release down with it, and its output is
# the diagnosis - "mc: <ERROR> Deprecated command" rather than "Job has reached
# the specified backoff limit". Its pod is treated separately from the pods
# above because the Job controller deletes it the moment the backoff limit is
# exceeded, which is often a second or two before anyone looks.
hdr "jobs that did not complete"
jobs=$("${kc[@]}" get jobs -o json 2>/dev/null \
    | jq -r '.items[] | select((.status.succeeded // 0) < 1) | .metadata.name' 2>/dev/null)

if [ -z "$jobs" ]; then
    echo "(none - no job is stuck or failed)"
else
    for job in $jobs; do
        echo "== job/$job"
        "${kc[@]}" get job "$job" -o json 2>/dev/null | jq -r '
            (.status.conditions // [])[]
            | "    \(.type)=\(.status) \(.reason // ""): \(.message // "")"' 2>/dev/null
        out=$("${kc[@]}" logs "job/$job" --all-containers --tail="$TAIL_LINES" 2>&1)
        if [ -n "$out" ] && ! grep -q 'no pods found\|not found' <<< "$out"; then
            echo "$out" | sed 's/^/    /'
        else
            # The pod is gone, so its log went with it. Say so rather than
            # leaving a silent gap, and name what would have held the answer.
            echo "    no pod left to read the log from - the Job controller"
            echo "    deleted it. kubectl -n $NAMESPACE describe job $job, and"
            echo "    the events above, are what remains."
        fi
    done
fi

hdr "events, oldest first"
"${kc[@]}" get events --sort-by=.lastTimestamp 2>&1 | tail -30

# Only the pods that are actually unhealthy: the logs of a working opensearch
# are noise, and burying the one broken container in them is how this stops
# being read.
hdr "logs of the pods that are not ready (last $TAIL_LINES lines each)"
pods=$("${kc[@]}" get pods -o json 2>/dev/null | jq -r '
    .items[]
    | select([ ((.status.initContainerStatuses // [])[]),
               ((.status.containerStatuses     // [])[]) ]
             | map(.ready == true) | all | not)
    | .metadata.name' 2>/dev/null)

if [ -z "$pods" ]; then
    echo "(every pod is ready - the failure is not a pod that would not start)"
else
    for pod in $pods; do
        echo "== $pod"
        "${kc[@]}" logs "$pod" --all-containers --tail="$TAIL_LINES" 2>&1 | tail -"$TAIL_LINES"
        # A CrashLoopBackOff has already restarted, so the interesting output is
        # in the dead container, not in the one that is booting right now.
        prev=$("${kc[@]}" logs "$pod" --all-containers --previous --tail="$TAIL_LINES" 2>/dev/null)
        [ -n "$prev" ] && { echo "== $pod (previous attempt)"; echo "$prev"; }
    done
fi

exit 0
