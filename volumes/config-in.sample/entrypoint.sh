#!/bin/sh

# add missing package
apk add envsubst

function failed() {
    if [ -z "$1" ]
    then
        echo 'Premature end of process: FAILURE!'
    else
        echo "Premature end of process: $*"
    fi

    exit 1
}

function parse_mustache() {
    for f in "$@"
    do
        [ -z "$f" ] || [ ! -f "$f" ] && failed "Unable to parse file '$f': file not found!"

        [[ "$f" =~ .*~$ ]] || sed 's/\$/sdDolLaRSigNe€/g;s/{{\([A-Za-z0-9_]*\)}}/${\1}/g' "$f" \
            | envsubst \
            | sed 's/sdDolLaRSigNe€/$/g'
    done
}

for f in $(find "${INPUT_CONFIG_PATH}" -type f -iname '*.sample.*')
do
    fn=$(echo $f | sed 's/\.sample//g' )
    parse_mustache $f > $fn
done

# With unique tenant, uncomment next line
python3 /srv/qwc_service/config_generator_cli.py "${INPUT_CONFIG_PATH}/default/tenantConfig.json" all \
 || failed "Unable to launch config_generator_cli"


# Set the correct permissions to config-out
chown -R "$SERVICE_UID":"$SERVICE_GID" "${OUTPUT_CONFIG_PATH}" \
 || failed "Unable to launch chown"

# default qwc-config-generator entrypoint
HOME=/tmp uwsgi --http-socket :9090 --buffer-size $REQ_HEADER_BUFFER_SIZE --processes $UWSGI_PROCESSES \
    --threads $UWSGI_THREADS --plugins python3 $UWSGI_EXTRA --protocol uwsgi --wsgi-disable-file-wrapper \
    --uid $SERVICE_UID --gid $SERVICE_GID --master --chdir /srv/qwc_service --mount $SERVICE_MOUNTPOINT=server:app \
    --manage-script-name \
    || failed "Unable to launch uwsgi"

# echo "================== WILL EXEC $@"
# exec "$@" \
#     || failed "Unable to launch exec"
