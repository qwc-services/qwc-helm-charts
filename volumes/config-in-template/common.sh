#!/bin/sh

function logInfo() {
    echo -e -n "$(date +'%Y-%m-%d %H:%M:%S') ======================== "
    echo -e -n "$1: "
    echo "$2"
}

function failed() {
    if [ -z "$1" ]; then
        echo 'Premature end of process: FAILURE!'
    else
        echo "Premature end of process: $*"
    fi

    exit 1
}

function parse_mustache() {
    for f in "$@"; do
        [ -z "$f" ] || [ ! -f "$f" ] && failed "Unable to parse file '$f': file not found!"

        [[ "$f" =~ .*~$ ]] || sed 's/\$/sdDolLaRSigNe€/g;s/{{\([A-Za-z0-9_]*\)}}/${\1}/g' "$f" |
            envsubst |
            sed 's/sdDolLaRSigNe€/$/g'
    done
}

# for each sample file, replace {{ ENV_VAR }} by env var value
# first parameter is the directory to parse files
# second parameter is file type to parse
function parse_inplace() {
    for f in $(find "$1" -type f -iname "$2"); do
        parse_mustache $f >$f.tmp &&
            mv $f.tmp $f
    done
}

function refresh_configin() {
    logInfo "Refresh_configin" "Rsync from $1 to ${INPUT_CONFIG_PATH}"
    # copy template config in to destination directory
    rsync -auv $1/* ${INPUT_CONFIG_PATH}/

    # remove useless entrypoint.sh file
    rm ${INPUT_CONFIG_PATH}/entrypoint.sh

    logInfo "Refresh_configin" "Parsing env vars..."
    # for each sample file, replace {{ ENV_VAR }} by env var value
    parse_inplace "${INPUT_CONFIG_PATH}" '*.json'

    logInfo "Refresh_configin" "Done!"
}
