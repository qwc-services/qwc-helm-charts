#!/bin/sh

# With unique tenant, uncomment next line
python3 /srv/qwc_service/config_generator_cli.py ${INPUT_CONFIG_PATH}/default/tenantConfig.json all


# Set the correct permissions to config-out
chown -R $SERVICE_UID:$SERVICE_GID /srv/qwc_service/config-out

# default qwc-config-generator entrypoint
uwsgi --http-socket :9090 --buffer-size $REQ_HEADER_BUFFER_SIZE --processes $UWSGI_PROCESSES \
    --threads $UWSGI_THREADS $UWSGI_EXTRA --plugins python3 --protocol uwsgi --wsgi-disable-file-wrapper \
    --uid $SERVICE_UID --gid $SERVICE_GID --master --chdir /srv/qwc_service --mount $SERVICE_MOUNTPOINT=server:app \
    --manage-script-name

exec "$@"
