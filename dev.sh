#!/bin/bash

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR=${SCRIPT_DIR}

if [ "$TURNBASE_DEV" == "true" ]; then
    echo "Already in a turnbase shell!"
    exit 1
fi

# detects non-interactive because no PS1
if [ "x$PS1" = "x" ]; then
    exec bash --rcfile "${SCRIPT_DIR}/dev.sh"
fi

if [ -e ~/.bashrc ]; then
    set +e
    source ~/.bashrc
    set -e
fi

export TURNBASE_DEV=true
export PATH=${PATH}:${ROOT_DIR}/scripts

function setup_node_path {
    # TODO: this default path is probably system dependent...
    default_path=/usr/local/lib/node_modules
    export NODE_PATH=${NODE_PATH}:${default_path}:${ROOT_DIR}
}
setup_node_path

PS1="\[\e[5;31;1m\]turnbase\[\e[0m\] $PS1"
export PS1

unset SCRIPT_DIR
set +e
