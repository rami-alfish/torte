#!/bin/bash
# The following line uses curl to reproducibly install and run the specified revision of torte.
# Alternatively, torte can be installed manually (see https://github.com/ekuiter/torte).
# In that case, make sure to check out the correct revision manually and run ./torte.sh <this-file>.
TORTE_REVISION=38c329c; [[ $TOOL != torte ]] && builtin source <(curl -fsSL https://raw.githubusercontent.com/ekuiter/torte/$TORTE_REVISION/torte.sh) "$@"

experiment-subjects() {
    add-linux-kconfig-sample --interval "$(interval weekly)"
}

experiment-stages() {
    clone-systems
    read-statistics skip-sloc
    extract-kconfig-models-with --extractor kmax
    join-into read-statistics kconfig
}

# can be executed from output directory to copy and rename model files
copy-models() {
    mkdir -p models
    for f in kconfig/linux/*.model; do
        local revision
        revision=$(echo "$f" | cut -d/ -f3 | cut -d'[' -f1)
        cp "$f" "models/$(grep -E "^$revision," < read-statistics/output.csv | cut -d, -f 3).model"
    done
}