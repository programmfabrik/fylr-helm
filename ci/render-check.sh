#!/usr/bin/env bash
#
# Render every case in ci/render-cases/ and validate the manifests against the
# Kubernetes API schemas (#80603).
#
# A case file is named <chart>-<nn>-<slug>.yaml and is a values overlay for
# charts/<chart>. Rendering catches template errors; kubeconform catches
# manifests that render but no API server would accept — a field the chart
# spells wrong, an apiVersion that was removed, a value of the wrong type.
#
# Needs no cluster, so this is the check that runs on every push.
#
#   KUBE_VERSION   API version to validate against (default 1.31.0)
#   OUT            where the rendered manifests are written (default _render)

set -euo pipefail
cd "$(dirname "$0")/.."

KUBE_VERSION=${KUBE_VERSION:-1.31.0}
OUT=${OUT:-_render}

# Kubernetes' own schemas do not cover CRDs, and two cases render a Prometheus
# Operator monitor. Without the catalog those resources are skipped, which
# reads as a pass.
CRDS='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

rm -rf "$OUT"
mkdir -p "$OUT"

failed=()
for case_file in ci/render-cases/*.yaml; do
    name=$(basename "$case_file" .yaml)
    chart=${name%%-*}
    printf '%-42s ' "$name"

    if ! helm template "ci-$chart" "charts/$chart" -f "$case_file" > "$OUT/$name.yaml" 2> "$OUT/$name.err"; then
        echo "RENDER FAILED"
        sed 's/^/    /' "$OUT/$name.err"
        failed+=("$name")
        continue
    fi

    if ! result=$(kubeconform -strict -summary \
        -kubernetes-version "$KUBE_VERSION" \
        -schema-location default -schema-location "$CRDS" \
        "$OUT/$name.yaml" 2>&1); then
        echo "INVALID"
        echo "$result" | sed 's/^/    /'
        failed+=("$name")
        continue
    fi
    echo "${result#Summary: }"
done

if [ ${#failed[@]} -gt 0 ]; then
    echo
    echo "failed: ${failed[*]}"
    exit 1
fi
