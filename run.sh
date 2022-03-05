#!/bin/bash

shopt -s extglob
READERS=(kconfigreader kclause)

rm -rf dimacs_files kconfig_to_dimacs/data_*
mkdir dimacs_files

for reader in ${READERS[@]}; do
    # build Docker image
    docker build -f kconfig_to_dimacs/$reader/Dockerfile -t $reader kconfig_to_dimacs
    
    # optionally, run interactive session for debugging
    # docker run -it $reader

    # run evaluation script inside Docker container
    # for other evaluations, you can run other scripts (e.g., extract_all.sh)
    docker run -it --name $reader $reader ./extract_cnf.sh

    # copy evaluation results from Docker into main machine
    docker cp $reader:/home/data kconfig_to_dimacs/data_$reader

    # remove Docker container
    docker rm -f $reader
    
    # arrange DIMACS files for further processing
    for system in kconfig_to_dimacs/data_$reader/models/*; do
        system=$(basename $system)
        for file in kconfig_to_dimacs/data_$reader/models/$system/*.@(dimacs|model); do
            file=$(basename $file)
            if [[ $file == *".dimacs" ]]; then
                newfile=${file/$reader/$reader,$reader}
            else
                newfile=$file
            fi
            cp kconfig_to_dimacs/data_$reader/models/$system/$file dimacs_files/$system,$newfile
        done
    done
done

# clean up failures
rm -f dimacs/freetz-ng*kconfigreader* # fails due to memory overflow
rm -f dimacs/embtoolkit*kclause* # fails due to ?