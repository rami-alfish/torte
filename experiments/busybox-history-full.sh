#!/bin/bash
# The following line uses curl to reproducibly install and run the specified revision of torte.
# Alternatively, torte can be installed manually (see https://github.com/ekuiter/torte).
# In that case, make sure to check out the correct revision manually and run ./torte.sh <this-file>.
TORTE_REVISION=cf04358; [[ $TOOL != torte ]] && builtin source <(curl -fsSL https://raw.githubusercontent.com/ekuiter/torte/$TORTE_REVISION/torte.sh) "$@"

experiment-subjects() {
    add-busybox-kconfig-history --from 1_3_0 --to 1_37_0
    add-busybox-kconfig-history-full
}

experiment-stages() {
    clone-systems
    generate-busybox-models
    read-statistics
    extract-kconfig-models-with --extractor kmax
    join-into read-statistics kconfig
    transform-models-with-featjar --transformer model_to_uvl_featureide --output-extension uvl --timeout "$TIMEOUT"
    transform-models-into-dimacs --timeout "$TIMEOUT"
}

# can be executed from output directory to copy and rename model files
copy-models() {
    shopt -s globstar
    mkdir -p models
    for f in kconfig/**/*.model; do
        local revision
        local original_revision
        revision=$(basename "$f" .model | cut -d'[' -f1)
        original_revision=$(basename "$f" .model | cut -d'[' -f2 | cut -d']' -f1)
        cp "$f" "models/$(date -d "@$(grep -E "^$revision," < read-statistics/output.csv | cut -d, -f4)" +"%Y%m%d%H%M%S")-$original_revision.model"
    done
    shopt -u globstar
    # shellcheck disable=SC2207,SC2012
    f=($(ls models/*.model | sort -V | tr '\n' ' '))
    for ((i = 0; i < ${#f[@]}-1; i++)); do
        if diff -q "${f[i]}" "${f[i+1]}" >/dev/null; then
            echo "${f[i]}" and "${f[i+1]}" are duplicate >&2
        fi
    done
}