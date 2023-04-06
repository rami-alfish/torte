#!/bin/bash

experiment-subjects() {
    for revision in $(git-revisions busybox | exclude-revision pre alpha rc | start-at-revision 1_3_0); do
        add-revision --system busybox --revision "$revision"
        add-kconfig \
            --system busybox \
            --revision "$revision" \
            --kconfig-file Config.in \
            --kconfig-binding-files scripts/kconfig/*.o
    done
}

experiment-stages() {
    extract-with(extractor) {
        run \
            --stage "$extractor" \
            --image "$extractor" \
            --command "extract-with-$extractor"
    }

    transform-with-featjar(transformer, output_extension, command=transform-with-featjar) {
        run \
            --stage "$transformer" \
            --image featjar \
            --input-directory kconfig \
            --command "$command" \
            --input-extension model \
            --output-extension "$output_extension" \
            --transformer "$transformer" \
            --timeout 10
    }

    transform-into-dimacs-with-featjar() {
        transform-with-featjar --command transform-into-dimacs-with-featjar --output-extension dimacs "$@"
    }

    run --stage clone-systems
    extract-with --extractor kconfigreader
    extract-with --extractor kmax
    aggregate \
        --stage kconfig \
        --stage-field extractor \
        --file-fields binding-file,model-file \
        --stages kconfigreader kmax
    
    transform-with-featjar --transformer model_to_xml_featureide --output-extension xml
    transform-with-featjar --transformer model_to_uvl_featureide --output-extension uvl
    transform-with-featjar --transformer model_to_model_featureide --output-extension featureide.model
    transform-with-featjar --transformer model_to_smt_z3 --output-extension smt
    transform-into-dimacs-with-featjar --transformer model_to_dimacs_featureide
    transform-into-dimacs-with-featjar --transformer model_to_dimacs_featjar

    run \
        --stage model_to_dimacs_kconfigreader \
        --image kconfigreader \
        --input-directory model_to_model_featureide \
        --command transform-into-dimacs-with-kconfigreader \
        --input-extension featureide.model \
        --timeout 10
    join-into model_to_model_featureide model_to_dimacs_kconfigreader

    run \
        --stage smt_to_dimacs_z3 \
        --image z3 \
        --input-directory model_to_smt_z3 \
        --command transform-into-dimacs-with-z3 \
        --timeout 10
    join-into model_to_smt_z3 smt_to_dimacs_z3

    aggregate \
        --stage dimacs \
        --directory-field dimacs-transformer \
        --file-fields dimacs-file \
        --stages model_to_dimacs_featureide model_to_dimacs_kconfigreader smt_to_dimacs_z3
    join-into kconfig dimacs
}