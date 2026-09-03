#!/bin/bash
# Run the chart CI on any machine, the way .github/workflows/chart-ci.yml runs
# it on a GitHub runner: render and validate every case, bring up a throwaway
# minikube, install the chart into it, drive the API through the ingress, then
# tear the whole thing down again.
#
#   ./test_local.sh              full run, cleans up afterwards
#   K8S=1.36.0 ./test_local.sh   the other kubernetes version in the matrix
#   KEEP=1 ./test_local.sh       leave the cluster up and browse it
#   ./test_local.sh clean        tear down what an aborted run left
#
# Needs helm, kubectl, minikube, kubeconform, jq, curl and a docker the current
# user may talk to. It assumes nothing else: no helm repos registered, no
# kubeconfig, no minikube - a fresh clone on a fresh machine is enough.
#
# Everything it creates outside the cluster lands in /tmp/test_helm - minikube's
# home, the kubeconfig, kubectl's and helm's caches, helm's repo list - so the
# run touches no state of yours, writes nothing into the clone, and leaves
# nothing behind. Set WORK to put it somewhere else.
#
# The cluster runs in its own minikube profile, so an unrelated minikube on the
# same machine is never touched. As root the docker driver needs --force; that
# is the one way this differs from the GitHub runner, which runs unprivileged.

set -o pipefail

cd "$(dirname "$0")" || exit 1
export PATH=/usr/local/bin:$PATH

K8S=${K8S:-1.33.0}
PROFILE=${PROFILE:-test-helm}
RELEASE=${RELEASE:-testinstance}   # values.yaml hard-codes testinstance-minio
NAMESPACE=${NAMESPACE:-fylr-ci}
KEEP=${KEEP:-}

# Where a browser reaches this instance. The cluster lives inside a docker
# network nothing outside the machine can route to, so minikube publishes the
# ingress on a port of the machine itself and fylr is told to expect exactly
# that address - a Host header that disagrees with fylr.externalURL earns a
# redirect to it, not a page.
#
# The address is the one this machine talks to the internet with, which is what
# `ip route get` reports. Reading `ip addr` instead would have to choose
# between it and the docker and libvirt bridges.
PUBLISH_PORT=${PUBLISH_PORT:-9095}
HOST_IP=${HOST_IP:-$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')}
[ -n "$HOST_IP" ] || HOST_IP=$(ip -o -4 addr show scope global | awk 'NR==1{split($4,a,"/"); print a[1]}')
[ -n "$HOST_IP" ] || { echo "cannot work out this machine's address - set HOST_IP"; exit 1; }
EXTERNAL_URL=${EXTERNAL_URL:-http://$HOST_IP:$PUBLISH_PORT}
BROWSE_HOST=${EXTERNAL_URL#http://}

# Keep every bit of tool state in one throwaway directory instead of in $HOME.
# It makes the run reproducible - helm starts with no repositories, minikube
# with no cache, exactly like the runner - and the cleanup a single rm.
WORK=${WORK:-/tmp/test_helm}
mkdir -p "$WORK" || exit 1
export MINIKUBE_HOME=$WORK/minikube
export KUBECONFIG=$WORK/kubeconfig
export HELM_REPOSITORY_CONFIG=$WORK/helm/repositories.yaml
export HELM_REPOSITORY_CACHE=$WORK/helm/repository
export HELM_CACHE_HOME=$WORK/helm/cache
export HELM_CONFIG_HOME=$WORK/helm/config
export HELM_DATA_HOME=$WORK/helm/data

# kubectl keeps its discovery cache in ~/.kube/cache no matter which kubeconfig
# it is pointed at, and --cache-dir is the only way to move it. minikube shells
# out to its own bundled kubectl, which this does not reach - hence the note.
kubectl(){ command kubectl --cache-dir="$WORK/kube-cache" "$@"; }

# ... so ~/.kube can still appear, written by minikube. Remove it afterwards
# only if it was not there before: an existing one is yours, cache and all.
KUBE_DIR_EXISTED=0
[ -e "$HOME/.kube" ] && KUBE_DIR_EXISTED=1

step(){ printf "\n########## %s  [%s]\n" "$*" "$(date +%H:%M:%S)"; }

# Runs on success, on failure and on Ctrl-C, so an aborted run leaves no more
# behind than a finished one.
cleanup(){
    local rc=$?
    trap - EXIT INT TERM

    if [ -n "$KEEP" ]; then
        step "KEEP set - leaving profile $PROFILE up"
        echo "browse it at $EXTERNAL_URL - log in as root / admin"
        echo "kubectl needs the run's own config: export KUBECONFIG=$KUBECONFIG"
        echo "tear it down with: $0 clean"
        return $rc
    fi

    step "cleanup"
    if minikube status -p "$PROFILE" >/dev/null 2>&1; then
        helm uninstall "$RELEASE" --namespace "$NAMESPACE" --wait --timeout 5m 2>&1 | tail -2
        kubectl delete namespace "$NAMESPACE" --ignore-not-found --timeout=2m 2>&1 | tail -1
    fi
    minikube delete -p "$PROFILE" 2>&1 | tail -2
    rm -rf "$WORK" _render

    # Every image the run pulled lived inside the deleted cluster and went with
    # it. The kicbase image is the exception, it sits in the machine's docker.
    # Dropping it costs the download next time; docker refuses while any other
    # minikube still holds it, which is precisely the check we want.
    docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null \
        | grep '^gcr.io/k8s-minikube/kicbase:' \
        | xargs -r docker rmi >/dev/null 2>&1

    [ "$KUBE_DIR_EXISTED" = 0 ] && rm -rf "$HOME/.kube"

    echo "left behind:"
    git status --short
    return $rc
}
trap 'cleanup' EXIT
# HUP matters: a run started over ssh whose connection drops is killed by it,
# and without this the EXIT trap never fires and the cluster stays up.
trap 'exit 130' INT TERM HUP

if [ "$1" = "clean" ]; then
    exit 0   # the EXIT trap does the work
fi

# An earlier run that was killed hard leaves its cluster behind, and minikube
# start would happily adopt it - the install then upgrades a stale release
# instead of testing a fresh one. Start from nothing, always.
if minikube status -p "$PROFILE" >/dev/null 2>&1; then
    step "remove the cluster an earlier run left"
    minikube delete -p "$PROFILE" 2>&1 | tail -2
elif docker ps -aq --filter "name=^${PROFILE}$" | grep -q .; then
    step "remove the orphaned $PROFILE container an earlier run left"
    docker rm -f "$PROFILE" 2>&1 | tail -1
fi
rm -rf "$WORK" && mkdir -p "$WORK" || exit 1

step "render every case and validate the manifests (no cluster)"
./ci/render-check.sh || exit 1
if command -v ct >/dev/null; then
    make lint 2>&1 | tail -5 || exit 1
else
    echo "note: ct not installed, skipping the lint the render job also runs"
fi

step "register the chart repositories"
# helm dependency build resolves by URL but still insists the repository be
# registered, and this run starts with an empty repository list.
n=0
grep -hoE '^[[:space:]]+repository: https?://[^[:space:]]+' charts/*/Chart.yaml \
    | awk '{print $2}' | sort -u | while read -r url; do
        n=$((n+1))
        echo "  $url"
        helm repo add "dep$n" "$url" >/dev/null || exit 1
    done || exit 1

step "start minikube (kubernetes $K8S, profile $PROFILE)"
FORCE=""
[ "$(id -u)" = 0 ] && FORCE="--force"   # the docker driver refuses to run as root without it
minikube start -p "$PROFILE" --kubernetes-version="v$K8S" --driver=docker $FORCE \
    --cpus=max --memory=12g --addons=ingress,metrics-server \
    --ports="$PUBLISH_PORT:80" 2>&1 | tail -20 || exit 1
kubectl get nodes -o wide

step "build chart dependencies"
helm dependency build charts/fylr 2>&1 | tail -5 || exit 1

step "pull the fylr images into the cluster"
helm template "$RELEASE" charts/fylr -f ci/values-ci.yaml \
    | grep -oE 'image: "?docker\.fylr\.io/[^" ]+' \
    | sed -E 's/^image: "?//' | sort -u | tee "$WORK/images.txt"
while read -r img; do
    echo "== pulling $img"
    minikube image pull -p "$PROFILE" "$img" || exit 1
done < "$WORK/images.txt"

step "install the chart"
# The ingress rule loses its host: Kubernetes rejects an IP address as an
# Ingress host, and a rule without one answers whatever the browser sends.
helm upgrade --install "$RELEASE" charts/fylr \
    --namespace "$NAMESPACE" --create-namespace \
    -f ci/values-ci.yaml \
    --set "fylr.externalURL=$EXTERNAL_URL" \
    --set "ingress.hosts[0].host=" \
    --wait --timeout 20m 2>&1 | tail -20 || exit 1

# fylr connects its storage locations once at startup and never retries one that
# failed, while minio creates the bucket and the user in post-install hooks. See
# #80906, fixed in fylr 6.35.
step "restart fylr once minio finished its setup hooks"
if [ -n "$(kubectl -n "$NAMESPACE" get jobs -o name 2>/dev/null)" ]; then
    kubectl -n "$NAMESPACE" wait --for=condition=complete --timeout=5m job --all
fi
kubectl -n "$NAMESPACE" rollout restart deployment "$RELEASE-fylr"
kubectl -n "$NAMESPACE" rollout status deployment "$RELEASE-fylr" --timeout=10m || exit 1

step "smoke test the API"
APP_VERSION=$(awk -F'"' '/^appVersion:/ {print $2}' charts/fylr/Chart.yaml)
echo "chart appVersion: $APP_VERSION, reachable at $EXTERNAL_URL"
BASE="$EXTERNAL_URL" HOST="$BROWSE_HOST" EXPECT_VERSION="$APP_VERSION" \
    EXPECT_EXTERNAL_URL="$EXTERNAL_URL" \
    NAMESPACE="$NAMESPACE" EXECSERVER_SVC="svc/$RELEASE-execserver" \
    KUBE_CACHE_DIR="$WORK/kube-cache" ./ci/smoke.sh
SMOKE=$?

step "helm test"
helm test "$RELEASE" --namespace "$NAMESPACE" --timeout 10m 2>&1 | tail -20
HT=$?

kubectl -n "$NAMESPACE" get pods
step "RESULT smoke=$SMOKE helm-test=$HT"
exit $(( SMOKE || HT ))
