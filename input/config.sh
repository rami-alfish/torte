#!/bin/bash
# first, we set up the experiment's global variables
# next, we define the kconfig models to analyze
# finally, we define and combine analysis stages

export INPUT_DIRECTORY=input # path to system repositories
export OUTPUT_DIRECTORY=output # path to resulting outputs, created if necessary
export SKIP_DOCKER_BUILD= # y if building Docker images should be skipped, useful for loading imported images

experiment-stages() {
    run-stage 1 scripts/git/Dockerfile "$(input-directory)" ./clone-systems.sh
    run-stage 2 scripts/git/Dockerfile "$(input-directory)" ./tag-linux-versions.sh
    run-stage 3 scripts/git/Dockerfile "$(input-directory)" ./read-statistics.sh skip-sloc
    run-stage 4 scripts/kconfigreader/Dockerfile "$(input-directory)" ./extract-kconfig.sh
    run-stage 5 scripts/kclause/Dockerfile "$(input-directory)" ./extract-kconfig.sh
}

experiment-subjects() {
    add-system busybox https://github.com/mirror/busybox
    add-system linux https://github.com/torvalds/linux

    add-revision linux v2.5.45
    add-revision linux v2.5.46

    for revision in $(git-revisions busybox | exclude-revision pre alpha rc | grep 1_18_0); do
        add-kconfig busybox "$revision" scripts/kconfig/*.o Config.in ""
    done

    linux_env="ARCH=x86,SRCARCH=x86,KERNELVERSION=kcu,srctree=./,CC=cc,LD=ld,RUSTC=rustc"
    add-kconfig linux v2.6.13 scripts/kconfig/*.o arch/i386/Kconfig $linux_env
}

kconfig-post-checkout-hook() {
    system=$1
    revision=$2
    require-value system revision

    # the following hacks may impair accuracy, but are necessary to extract a kconfig model
    if [[ $system == freetz-ng ]]; then
        # ugly hack because freetz-ng is weird
        touch make/Config.in.generated make/external.in.generated config/custom.in
    fi
    if [[ $system == buildroot ]]; then
        touch .br2-external.in .br2-external.in.paths .br2-external.in.toolchains .br2-external.in.openssl .br2-external.in.jpeg .br2-external.in.menus .br2-external.in.skeleton .br2-external.in.init
        # ignore generated Kconfig files in buildroot
        find ./ -type f -name "*Config.in" -exec sed -i 's/source "\$.*//g' {} \;
    fi
    if [[ $system == toybox ]]; then
        mkdir -p generated
        touch generated/Config.in generated/Config.probed
    fi
    if [[ $system == linux ]]; then
        # ignore all constraints that use the newer $(success,...) syntax
        find ./ -type f -name "*Kconfig*" -exec sed -i "s/\s*default \$(.*//g" {} \;
        find ./ -type f -name "*Kconfig*" -exec sed -i "s/\s*depends on \$(.*//g" {} \;
        find ./ -type f -name "*Kconfig*" -exec sed -i "s/\s*def_bool \$(.*//g" {} \;
        # ugly hack for linux 6.0
        find ./ -type f -name "*Kconfig*" -exec sed -i "s/\s*def_bool ((.*//g" {} \;
        find ./ -type f -name "*Kconfig*" -exec sed -i "s/\s*(CC_IS_CLANG && CLANG_VERSION >= 140000).*//g" {} \;
        find ./ -type f -name "*Kconfig*" -exec sed -i "s/\s*\$(as-instr,endbr64).*//g" {} \;
    fi
}

# a version is sys,tag/revision,arch,iteration

#READERS="kconfigreader kclause" # Docker containers with Kconfig extractors
#READERS="kclause" # Docker containers with Kconfig extractors
#ANALYSES="void dead core" # analyses to run on feature models, see run-...-analysis functions
#ANALYSES="void" # analyses to run on feature models, see run-...-analysis functions
#N=
# ITERATIONS=1 # number of iterations
# TIMEOUT_TRANSFORM=180 # transformation timeout in seconds
# TIMEOUT_ANALYZE=1800 # analysis timeout in seconds
# RANDOM_SEED=2302101557 # seed for choosing core/dead features
# NUM_FEATURES=1 # number of randomly chosen core/dead features
# SKIP_ANALYSIS=n # whether to only extract and transform feature models, omitting an analysis
# MEMORY_LIMIT=128g # memory limit for Docker containers

# evaluated hierarchical feature models
#HIERARCHIES=""

# evaluated (#)SAT solvers
# we choose all winning SAT solvers in SAT competitions
# for #SAT, we choose the five fastest solvers as evaluated by Sundermann et al. 2021, found here: https://github.com/SoftVarE-Group/emse21-evaluation-sharpsat/tree/main/solvers
#SOLVERS="sharpsat-countAntom sharpsat-d4 sharpsat-dsharp sharpsat-ganak sharpsat-sharpSAT"
#SOLVERS="c2d d4 dpmc gpmc sharpsat-td-arjun1 sharpsat-td-arjun2 sharpsat-td twg"
#SOLVERS="d4"

# # in old versions, use kconfig-binding from 2.6.12
# for tag in $(git -C input/linux tag | grep -v rc | grep -v tree | sort -V | sed -n '/2.6.12/q;p'); do
# #for tag in $(git -C input/linux tag | grep -v rc | grep -v tree | sort -V | sed -n '/2.6.0/,$p' | sed -n '/2.6.4/q;p'); do
#     run linux https://github.com/torvalds/linux $tag /home/output/kconfig-bindings/linux/v2.6.12.$BINDING arch/i386/Kconfig $linux_env
# done

# for tag in $(git -C input/linux tag | grep -v rc | grep -v tree | sort -V | sed -n '/2.6.12/,$p'); do
#     if git -C input/linux ls-tree -r $tag --name-only | grep -q arch/i386; then
#         run linux https://github.com/torvalds/linux $tag scripts/kconfig/*.o arch/i386/Kconfig $linux_env # in old versions, x86 is called i386
#     else
#         run linux https://github.com/torvalds/linux $tag scripts/kconfig/*.o arch/x86/Kconfig $linux_env
#     fi
# done

# for tag in $(git -C input/linux tag | grep -v rc | grep -v tree | sort -V | sed -n '/2.6.35/,$p' | sed -n '/2.6.37/q;p'); do
#     if git -C input/linux ls-tree -r $tag --name-only | grep -q arch/i386; then
#         run linux https://github.com/torvalds/linux $tag scripts/kconfig/*.o arch/i386/Kconfig $linux_env # in old versions, x86 is called i386
#     else
#         run linux https://github.com/torvalds/linux $tag scripts/kconfig/*.o arch/x86/Kconfig $linux_env
#     fi
# done