#!/bin/bash
# The following line uses curl to reproducibly install and run the specified revision of torte.
# Alternatively, torte can be installed manually (see https://github.com/ekuiter/torte).
# In that case, make sure to check out the correct revision manually and run torte.sh <this-file>.
TORTE_REVISION=main; [[ -z $DOCKER_PREFIX ]] && builtin source <(curl -fsSL https://raw.githubusercontent.com/ekuiter/torte/$TORTE_REVISION/torte.sh) "$@"

experiment-subjects() {
    add-linux-kconfig-history
}

experiment-stages() {
    run --stage clone-systems
    run --stage tag-linux-revisions
    run --stage read-statistics
    #plot --stage read-statistics --type scatter --fields committer_date_unix,source_lines_of_code

    extract-with(extractor) {
        run \
            --stage "$extractor" \
            --image "$extractor" \
            --command "extract-with-$extractor"
    }
    
    extract-with kconfigreader
    extract-with kmax
    
    aggregate \
        --stage model \
        --stage-field extractor \
        --file-fields binding-file,model-file \
        --stages kconfigreader kmax
    join-into read-statistics model

    transform-with-featjar(transformer, output_extension, command=transform-with-featjar) {
        run \
            --stage "$transformer" \
            --image featjar \
            --input-directory model \
            --command "$command" \
            --input-extension model \
            --output-extension "$output_extension" \
            --transformer "$transformer"
    }

    transform-with-featjar --transformer model_to_smt_z3 --output-extension smt
    run \
        --stage dimacs \
        --image z3 \
        --input-directory model_to_smt_z3 \
        --command transform-into-dimacs-with-z3
    join-into model_to_smt_z3 dimacs
    join-into model dimacs

    local solver_specs=(
        # ase-2022/countAntom,solver,model-count # todo: currently only returns NA
        ase-2022/d4,solver,model-count
        # ase-2022/dsharp,solver,model-count
        ase-2022/ganak,solver,model-count
        ase-2022/sharpSAT,solver,model-count
    )
    local model_count_stages=()
    for solver_spec in "${solver_specs[@]}"; do
        local solver stage image parser
        solver=$(echo "$solver_spec" | cut -d, -f1)
        stage=${solver//\//_}
        stage=solve_${stage,,}
        image=$(echo "$solver_spec" | cut -d, -f2)
        parser=$(echo "$solver_spec" | cut -d, -f3)
        model_count_stages+=("$stage")
        run \
            --stage "$stage" \
            --image "$image" \
            --input-directory dimacs \
            --command solve --solver "$solver" --parser "$parser" --timeout 300
    done
    aggregate --stage solve_model_count --stages "${model_count_stages[@]}"
    join-into dimacs solve_model_count
}