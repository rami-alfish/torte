#!/bin/bash

if [[ -d "kconfigreader" ]]; then
    READER=kconfigreader
elif [[ -d "kmax" ]]; then
    READER=kclause
else
    echo "no reader found, please run script inside of Docker"
    exit 1
fi
LOG=/home/data/log_$READER.txt
SYSTEMS=/home/data/systems_$READER.csv
MODELS=/home/data/models_$READER.csv
if [ $READER = kconfigreader ]; then
    BINDING=dumpconf
    TAGS="kconfigreader|rsf|features|model|dimacs|cnf|tseitin"
elif [ $READER = kclause ]; then
    BINDING=kextractor
    TAGS="kmax|kclause|features|model|dimacs|cnf|tseitin"
else
    echo "invalid reader"
    exit 1
fi
BINDING_ENUMS=(S_UNKNOWN S_BOOLEAN S_TRISTATE S_INT S_HEX S_STRING S_OTHER P_UNKNOWN P_PROMPT P_COMMENT P_MENU P_DEFAULT P_CHOICE P_SELECT P_RANGE P_ENV P_SYMBOL E_SYMBOL E_NOT E_EQUAL E_UNEQUAL E_OR E_AND E_LIST E_RANGE E_CHOICE P_IMPLY E_NONE E_LTH E_LEQ E_GTH E_GEQ dir_dep)
N=${N:-1}

cd /home
mkdir -p data
echo -n > $LOG
echo -n > $MODELS
echo system,tag,c-binding,kconfig-file,tags >> $MODELS

# compiles the C program that extracts Kconfig constraints from Kconfig files
# for kconfigreader and kclause, this compiles dumpconf and kextractor against the Kconfig parser, respectively
c-binding() (
    if [ $2 = buildroot ]; then
        find ./ -type f -name "*Config.in" -exec sed -i 's/source "\$.*//g' {} \; # ignore generated Kconfig files in buildroot
    fi
    set -e
    mkdir -p /home/data/c-bindings/$2
    args=""
    binding_files=$(echo $4 | tr , ' ')
    binding_dir=$(dirname $binding_files | head -n1)
    for enum in ${BINDING_ENUMS[@]}; do
        if grep -qrnw $binding_dir -e $enum; then
            args="$args -DENUM_$enum"
        fi
    done
    # make sure all dependencies for the C program are compiled
    # make config sometimes asks for integers (not easily simulated with "yes"), which is why we add a timeout
    make $binding_files >/dev/null || (yes | make allyesconfig >/dev/null) || (yes | make xconfig >/dev/null) || (yes "" | timeout 20s make config >/dev/null) || true
    strip -N main $binding_dir/*.o || true
    cmd="gcc /home/$1.c $binding_files -I $binding_dir -Wall -Werror=switch $args -Wno-format -o /home/data/c-bindings/$2/$3.$1"
    (echo $cmd >> $LOG) && eval $cmd
)

read-model() (
    # read-model kconfigreader|kclause system commit c-binding Kconfig tags env
    set -e
    mkdir -p /home/data/models/$2
    writeDimacs=--writeDimacs
    if [ -z "$7" ]; then
        env=""
    else
        env="$(echo '' -e $7 | sed 's/,/ -e /g')"
    fi
    # the following hacks may not lead to accurate results
    if [ $2 = freetz-ng ]; then
        touch make/Config.in.generated make/external.in.generated config/custom.in # ugly hack because freetz-ng is weird
        writeDimacs="" # Tseitin transformation crashes for freetz-ng (out of memory error)
    fi
    if [ $2 = buildroot ]; then
        touch .br2-external.in .br2-external.in.paths .br2-external.in.toolchains .br2-external.in.openssl .br2-external.in.jpeg .br2-external.in.menus .br2-external.in.skeleton .br2-external.in.init
    fi
    if [ $2 = toybox ]; then
        mkdir -p generated
        touch generated/Config.in generated/Config.probed
    fi
    if [ $2 = linux ]; then
        # ignore all constraints that use the newer $(success,...) syntax
        find ./ -type f -name "*Kconfig*" -exec sed -i 's/\s*default $(.*//g' {} \;
        find ./ -type f -name "*Kconfig*" -exec sed -i 's/\s*depends on $(.*//g' {} \;
        find ./ -type f -name "*Kconfig*" -exec sed -i 's/\s*def_bool $(.*//g' {} \;
    fi
    i=0
    while [ $i -ne $N ]; do
        i=$(($i+1))
        model="/home/data/models/$2/$3,$i,$1.model"
        dimacs="/home/data/models/$2/$3,$i,$1.dimacs"
        if [ $1 = kconfigreader ]; then
            cmd="/home/kconfigreader/run.sh de.fosd.typechef.kconfig.KConfigReader --fast --dumpconf $4 $writeDimacs $5 /home/data/models/$2/$3,$i,$1 | /home/measure_time | tee >(grep 'c time' >> $dimacs)"
            (echo $cmd | tee -a $LOG) && eval $cmd
            variables_extract=$(cat $dimacs | grep -E '^c [0-9]' | wc -l)
            literals_extract=$(cat $model 2>/dev/null | grep -Fo 'def(' | wc -l)
            echo "c variables_extract $variables_extract" >> $dimacs
            echo "c literals_extract $literals_extract" >> $dimacs
        elif [ $1 = kclause ]; then
            start=`date +%s.%N`
            cmd="$4 --extract -o /home/data/models/$2/$3,$i,$1.kclause $env $5"
            (echo $cmd | tee -a $LOG) && eval $cmd
            cmd="$4 --configs $env $5 > /home/data/models/$2/$3,$i,$1.features"
            (echo $cmd | tee -a $LOG) && eval $cmd
            if [ $2 = embtoolkit ]; then
                # fix incorrect feature names, which Kclause interprets as a binary subtraction operator
                sed -i 's/-/_/g' /home/data/models/$2/$3,$i,$1.kclause
            fi
            cmd="kclause < /home/data/models/$2/$3,$i,$1.kclause > $model"
            (echo $cmd | tee -a $LOG) && eval $cmd
            cmd="python3 /home/kclause2dimacs.py $model > $dimacs" # todo: remove, as this overlaps with spldev-z3
            (echo $cmd | tee -a $LOG) && eval $cmd
            end=`date +%s.%N`
            echo "c time $(echo "($end - $start) * 1000000000 / 1" | bc)" >> $dimacs
            echo "c variables_extract $(cat $dimacs | grep -E '^c [0-9]' | grep -v and | grep -v or | wc -l)" >> $dimacs
        fi
        echo "c variables_transform $(cat $dimacs | grep -E ^p | cut -d' ' -f3)" >> $dimacs
        echo "c clauses_transform $(cat $dimacs | grep -E ^p | cut -d' ' -f4)" >> $dimacs
        echo "c literals_transform $(cat $dimacs | grep -E "^[^pc]" | grep -Fo ' ' | wc -l)" >> $dimacs
        echo "c features $(wc -l /home/data/models/$2/$3,$i,$1.features | cut -d' ' -f1)" >> $dimacs
    done
)

git-checkout() (
    if [[ ! -d "$1" ]]; then
        echo "Cloning $1" | tee -a $LOG
        git clone $2 $1
    fi
    if [ ! -z "$3" ]; then
        cd $1
        git reset --hard
        git clean -fx
        git checkout -f $3
    fi
)

svn-checkout() (
    rm -rf $1
    svn checkout $2 $1
)

run() (
    set -e
    echo | tee -a $LOG
    if ! echo $4 | grep -q c-bindings; then
        binding_path=/home/data/c-bindings/$1/$3.$BINDING
    else
        binding_path=$4
    fi
    if [[ ! -f "/home/data/models/$1/$3.$READER.model" ]]; then
        trap 'ec=$?; (( ec != 0 )) && (rm -f /home/data/models/'$1'/'$3'.'$READER'* && echo FAIL | tee -a $LOG) || (echo SUCCESS | tee -a $LOG)' EXIT
        if [[ $2 != skip-checkout ]]; then
            echo "Checking out $3 in $1" | tee -a $LOG
            if [[ $2 == svn* ]]; then
                vcs=svn-checkout
                else
                vcs=git-checkout
            fi
            eval $vcs $1 $2 $3
        fi
        cd $1
        if [ ! $binding_path = $4 ]; then
            echo "Compiling C binding $BINDING for $1 at $3" | tee -a $LOG
            c-binding $BINDING $1 $3 $4
        fi
        if [[ $2 != skip-model ]]; then
            echo "Reading feature model for $1 at $3" | tee -a $LOG
            read-model $READER $1 $3 $binding_path $5 $6 $7
        fi
        cd /home
    else
        echo "Skipping feature model for $1 at $3" | tee -a $LOG
    fi
    echo $1,$3,$binding_path,$5,$6 >> $MODELS
)

list-systems() (
    echo -n > $SYSTEMS
    cd /home/data/models
    echo system,tag,features,variables,clauses | tee -a $SYSTEMS
    for system in *; do
        cd $system
        for file in $(ls *.$READER.model 2>/dev/null); do
	    tag=$(basename $file .$READER.model)
	    if ([ ! -f $tag.$READER.features ] || [ ! -f $tag.$READER.model ] || [ ! -f $tag.$READER.dimacs ]) ||
	        ([ $READER = kconfigreader ] && [ ! -f $tag.$READER.rsf ]) ||
	        ([ $READER = kmax ] && [ ! -f $tag.$READER.kclause ]); then
	        echo "WARNING: some files are missing for $system at $tag"
	    fi
	    if [ -f $tag.$READER.dimacs ]; then
	        /home/MiniSat_v1.14_linux $tag.$READER.dimacs > /dev/null
	        if [ $? -ne 10 ]; then
	            echo "WARNING: DIMACS for $system at $tag is unsatisfiable"
	        fi
	    fi
	    features=$(wc -l $tag.$READER.features | cut -d' ' -f1)
	    variables=$(cat $tag.$READER.dimacs 2>/dev/null | grep -E ^p | cut -d' ' -f3)
	    clauses=$(cat $tag.$READER.dimacs 2>/dev/null | grep -E ^p | cut -d' ' -f4)
	    echo $system,$tag,$features,$variables,$clauses | tee -a $SYSTEMS
        done
        cd ..
    done
)