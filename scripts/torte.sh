#!/bin/bash
# main entry point, runs whatever function it is passed
# behaves differently if run inside Docker

set -e # exit on error
trap "echo ERROR! >&2" ERR # set error handler

# API functions
api=(
    # implemented in config files
    experiment-stages # defines the stages of the experiment in order of their execution
    experiment-subjects # defines the experiment subjects
    kconfig-post-checkout-hook # called after a system has been checked out during kconfig model extraction
    kmax-post-binding-hook # called after a kconfig binding has been executed during kconfig model extraction

    # implemented in Docker containers
    add-system # adds a system (e.g., clone)
    add-revision # adds a system revision (e.g., read statistics)
    add-kconfig-binding # adds a kconfig binding (e.g., dumpconf or kextractor)
    add-kconfig-model # adds a kconfig model (e.g., a model read by kconfigreader or kmax)
    add-kconfig # adds a kconfig binding and model
)

SCRIPTS_DIRECTORY=$(dirname "$0") # scripts directory
DOCKER_PREFIX=torte # prefix for naming Docker images and containers
DOCKER_INPUT_DIRECTORY=/home/input # input directory inside Docker containers
DOCKER_OUTPUT_DIRECTORY=/home/output # output directory inside Docker containers
DOCKER_OUTPUT_FILE_PREFIX=output # prefix for output files inside Docker containers
KCONFIG_MODELS_OUTPUT_DIRECTORY= # output directory for storing kconfig models
KCONFIG_BINDINGS_OUTPUT_DIRECTORY=kconfig-bindings # output directory for storing Kconfig bindings
TRANSIENT_STAGE=transient # name for transient stages
PATH_SEPARATOR=/ # separator for building paths
INPUT_DIRECTORY=input # path to system repositories
OUTPUT_DIRECTORY=output # path to resulting outputs, created if necessary
SKIP_DOCKER_BUILD= # y if building Docker images should be skipped, useful for loading imported images
MEMORY_LIMIT=$(($(sed -n '/^MemTotal:/ s/[^0-9]//gp' /proc/meminfo)/1024/1024)) # memory limit in GiB for running Docker containers and other tools, should be at least 2 GiB
FORCE_RUN= # y if every stage should be forced to run regardless of whether is is already done
VERBOSE= # y if console output should be verbose

source "$SCRIPTS_DIRECTORY/bootstrap.sh" # modifies bash to allow for succinct function definitions
source "$SCRIPTS_DIRECTORY/helper.sh" # miscellaneous helpers
source "$SCRIPTS_DIRECTORY/path.sh" # functions for dealing with input/output paths
source "$SCRIPTS_DIRECTORY/stage.sh" # functions for running stages
source "$SCRIPTS_DIRECTORY/experiment.sh" # functions for running experiments
source "$SCRIPTS_DIRECTORY/docker.sh" # functions for working with Docker containers
source "$SCRIPTS_DIRECTORY/util.sh" # functions for working with Git repositories and other utilities
source "$SCRIPTS_DIRECTORY/extraction.sh" # functions for extracting kconfig models
source "$SCRIPTS_DIRECTORY/transformation.sh" # functions for transforming files

# prints help information
command-help() {
    echo "usage: $(basename "$0") [experiment_file] [command [option]...]"
    echo
    echo "experiment_file (default: experiments/default.sh)"
    echo
    echo "command (default: run)"
    echo "  run                 runs the experiment"
    echo "  clean               removes all output files for the experiment"
    echo "  stop                stops the experiment"
    echo "  export [directory]  saves all experiment-related Docker images, input, and output into the given directory"
    echo "  import [directory]  loads all Docker images from the given directory"
    echo "  reset               removes all Docker containers and images"
    echo "  browse              start a web server for browsing output files"
    echo "  help                prints help information"
}

# define stubs for API functions
for function in "${api[@]}"; do
    define-stub "$function"
done

# load experiment file
# todo: self-executing experiment file
arguments=("$@")
if [[ ${#arguments[@]} -ge 1 ]] && [[ -f "${arguments[0]}" ]]; then 
    load-experiment "${arguments[0]}"
    arguments=("${arguments[@]:1}")
else
    load-experiment
fi

# run the given command
if [[ -z "${arguments[*]}" ]]; then
    arguments=(run)
fi
function=${arguments[0]}
if is-host && has-function "command-$function"; then
    function=command-$function
fi
"$function" "${arguments[@]:1}"
