#!/bin/bash
# The following line uses curl to reproducibly install and run the specified revision of torte.
# Alternatively, torte can be installed manually (see https://github.com/ekuiter/torte).
# In that case, make sure to check out the correct revision manually and run ./torte.sh <this-file>.
TORTE_REVISION=7e88865; [[ $TOOL != torte ]] && builtin source <(curl -fsSL https://raw.githubusercontent.com/ekuiter/torte/$TORTE_REVISION/torte.sh) "$@"

experiment-subjects() {
    add-linux-kconfig-sample --interval "$(interval weekly)"
}

experiment-stages() {
    clone-systems
    read-statistics skip-sloc
    extract-kconfig-models-with --extractor kmax
    join-into read-statistics kconfig
}