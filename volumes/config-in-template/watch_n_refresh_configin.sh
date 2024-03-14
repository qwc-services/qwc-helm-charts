#!/bin/sh

ROOT_DIR=$(dirname $0)
source $ROOT_DIR/common.sh

logInfo Watch "Starting..."

[ -z "$(which inotifywait)" ] &&
    failed "inotifywait not installed. In most distros, it is available in the inotify-tools package."

# As inotify does not work with mount/nfs/remote directories we have to create a tmp dir then
# rsync the source dir to this temp dir in order to have inotify to catch fs events.
#
# inotify could be replaced by fswatch but it is NOT available for alpinelinux.
#
# rsync is ran every 5 seconds.
#
mkdir /tmp/template
rsync_cmd="rsync -au ${INPUT_CONFIG_PATH}-template/ /tmp/template/"
eval $rsync_cmd
(watch -n 2 eval $rsync_cmd) &

counter=0

# avail event: modify,move,create,delete
inotifywait --recursive --monitor --format "%e %w%f" \
    --event modify /tmp/template/ |
    while read changed; do
        counter=$((counter + 1))
        logInfo Watch "has detected change! $counter times"
        echo $changed
        refresh_configin /tmp/template
    done

logInfo Watch "Stopped!"
