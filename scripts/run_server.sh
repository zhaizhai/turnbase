#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR=$SCRIPT_DIR/..

if [ -z $TURNBASE_DEV ]; then
    echo "Must run while in turnbase shell! (run ./dev.sh first)"
    exit 1
fi

# # kill this whole process group on exit, including bot server
# trap "kill 0" EXIT
# # TODO: I am not sure how robust this is. We don't need it for now
# # because nodemon appears to take care of it for us; in fact, kill 0
# # would kill nodemon as well.

run_bot_server() {
    sleep 5; # TODO: hack in lieu of detecting when main server has
             # started
    echo "Starting $1-$2 bot server"
    iced ${ROOT_DIR}/bots/bot_server.iced $1 $2 &> ${ROOT_DIR}/logs/$1-$2.log
}
# run_bot_server fiverow fiverowbot &
# run_bot_server tichu tichubot &
# run_bot_server deduxi deduxibot &
# run_bot_server liars_dice liarbot &

iced ${ROOT_DIR}/server/index.iced
