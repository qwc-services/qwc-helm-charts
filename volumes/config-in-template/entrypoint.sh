#!/bin/sh

ROOT_DIR=$(dirname $0)
source $ROOT_DIR/common.sh

logInfo "Entrypoint" "Installing dep packages..."

# add missing package
apk add envsubst rsync inotify-tools

if [ ! -f "${INPUT_CONFIG_PATH}/default/tenantConfig.json" ]; then
    logInfo "Entrypoint" "Empty config in ==> first sync!"
    refresh_configin ${INPUT_CONFIG_PATH}-template/
fi

$ROOT_DIR/watch_n_refresh_configin.sh &

logInfo "Entrypoint" "Generating config..."
# With unique tenant, uncomment next line
python3 /srv/qwc_service/config_generator_cli.py "${INPUT_CONFIG_PATH}/default/tenantConfig.json" all ||
    failed "Unable to launch config_generator_cli"

# Set the correct permissions to config-generated
chown -R "$SERVICE_UID":"$SERVICE_GID" "${OUTPUT_CONFIG_PATH}" ||
    failed "Unable to apply chown"

logInfo "Entrypoint" "Starting UWSGI..."
# default qwc-config-generator entrypoint
HOME=/tmp uwsgi --http-socket :9090 --buffer-size $REQ_HEADER_BUFFER_SIZE --processes $UWSGI_PROCESSES \
    --threads $UWSGI_THREADS --plugins python3 $UWSGI_EXTRA --protocol uwsgi --wsgi-disable-file-wrapper \
    --uid $SERVICE_UID --gid $SERVICE_GID --master --chdir /srv/qwc_service --mount $SERVICE_MOUNTPOINT=server:app \
    --manage-script-name ||
    failed "Unable to launch uwsgi"
