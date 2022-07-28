#!/bin/bash

git-checkout() (
    if [[ ! -d "input/$1" ]]; then
        echo "Cloning $1" | tee -a $LOG
        echo $2 $1
        git clone $2 input/$1
    fi
)

run() (
    set -e
    if [[ $2 != skip-model ]] && ! echo $KCONFIG | grep -q $1,$3; then
        exit
    fi
    if [[ $2 != skip-checkout ]]; then
        eval git-checkout $1 $2 $3
    fi
)