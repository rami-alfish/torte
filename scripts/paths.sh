#!/bin/bash

# returns the root input directory
input-directory() {
    if [[ -z $DOCKER_RUNNING ]]; then
        echo "$INPUT_DIRECTORY"
    else
        echo "$DOCKER_INPUT_DIRECTORY"
    fi
}

# returns the directory for all outputs for a given stage
output-directory() {
    if [[ -z $DOCKER_RUNNING ]]; then
        local stage=$1
        require-value stage
        echo "$OUTPUT_DIRECTORY/$stage"
    else
        echo "$DOCKER_OUTPUT_DIRECTORY"
    fi
}

# returns a file with a given extension for the input of the current stage
input-file() {
    local extension=$1
    require-value extension
    echo "$(input-directory)/$DOCKER_OUTPUT_FILE_PREFIX.$extension"
}

# returns a file with a given extension for the output of a given stage
output-file() {
    local extension=$1
    local stage=$2
    require-value extension
    echo "$(output-directory "$stage")/$DOCKER_OUTPUT_FILE_PREFIX.$extension"
}

# standard files for experimental results, human-readable output, and human-readable errors
input-csv() { input-file csv; }
input-log() { input-file log; }
input-err() { input-file err; }
output-csv() { output-file csv "$1"; }
output-log() { output-file log "$1"; }
output-err() { output-file err "$1"; }

# returns whether the given experiment stage is done
stage-done() {
    local stage=$1
    require-host
    require-value stage
    [[ -d $(output-directory "$stage") ]]
}

# requires that he given experiment stage is done
require-stage-done() {
    local stage=$1
    require-host
    require-value stage
    if ! stage-done "$stage"; then
        error "Stage $stage not done yet, please run stage $stage."
    fi
}