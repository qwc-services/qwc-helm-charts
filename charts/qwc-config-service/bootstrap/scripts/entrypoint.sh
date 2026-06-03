#!/usr/bin/env bash
# shellcheck disable=SC2086,SC1091

ROOT_DIR=$(dirname "$0")
source $ROOT_DIR/common.sh

function generate_config() {
  [ -z "$1" ] && failed "Need first param: INPUT_CONFIG_PATH"
  INPUT_CONFIG_PATH="$1"
  [ -z "$2" ] && failed "Need second param: OUTPUT_CONFIG_PATH"
  OUTPUT_CONFIG_PATH="$2"

  logInfo "generate_config" "Will generate config from '${INPUT_CONFIG_PATH}' to '${OUTPUT_CONFIG_PATH}'"

  [ -d /srv/qwc_service/.venv ] || failed "No venv directory present!"

  # With unique tenant, uncomment next line
  # Activate virtualenv to access Python dependencies (jsonschema, etc.)
  source /srv/qwc_service/.venv/bin/activate

  uv run /srv/qwc_service/config_generator_cli.py "${INPUT_CONFIG_PATH}/default/tenantConfig.json" all \
    || failed "config_generator_cli crashed!"

  # Set the correct permissions to config-generated
  chown -R "$SERVICE_UID":"$SERVICE_GID" "${OUTPUT_CONFIG_PATH}" \
    || failed "Unable to apply chown"

  logInfo "generate_config" "Done!"
}

logInfo "Entrypoint" "Starting..."

for envvar in INPUT_CONFIG_PATH OUTPUT_CONFIG_PATH REQ_HEADER_BUFFER_SIZE UWSGI_PROCESSES \
  UWSGI_THREADS UWSGI_EXTRA SERVICE_UID SERVICE_GID SERVICE_MOUNTPOINT BOOTSTRAP_WATCHDOG_FILE; do
  [ -z "${!envvar+x}" ] && failed "'$envvar' env var must be defined."
done

logInfo "Entrypoint" "Checking content of '${INPUT_CONFIG_PATH}'"
ls -alR "${INPUT_CONFIG_PATH}/"

if [ ! -f "${INPUT_CONFIG_PATH}/${BOOTSTRAP_WATCHDOG_FILE}" ]; then
  logInfo "Entrypoint-bootstrap" "No config-in data (watchdog file '${INPUT_CONFIG_PATH}/${BOOTSTRAP_WATCHDOG_FILE}'). Will bootstrap..."
  configmap_to_files /bootstrap/config-in "$INPUT_CONFIG_PATH" "$BOOTSTRAP_WATCHDOG_FILE"

  if [ -n "$(which envsubst)" ]; then
    logInfo "Entrypoint-bootstrap" "Parsing env vars..."

    # for each sample file of default and qgis_projects, replace {{ ENV_VAR }} by env var value
    # it can not be executed on root $INPUT_CONFIG_PATH directory (strange errors will occur)
    parse_inplace "$INPUT_CONFIG_PATH/default" '*'
    parse_inplace "$INPUT_CONFIG_PATH/qgis_projects" '*'
  fi
else
  logInfo "Entrypoint" "Config-in data already present (watchdog file '${INPUT_CONFIG_PATH}/${BOOTSTRAP_WATCHDOG_FILE}'). Skipping bootstrap!"
fi

# When bootstrap is done and no config was never generated, generate first one.
if [ ! -f "${OUTPUT_CONFIG_PATH}/adminGuiConfig.json" ]; then
  generate_config "${INPUT_CONFIG_PATH}" "${OUTPUT_CONFIG_PATH}"
fi

logInfo "Entrypoint" "Starting UWSGI..."
# default qwc-config-generator entrypoint
HOME=/tmp uwsgi \
  --http-socket :9090 \
  --buffer-size $REQ_HEADER_BUFFER_SIZE \
  --processes $UWSGI_PROCESSES \
  --threads $UWSGI_THREADS \
  --plugins python3 $UWSGI_EXTRA \
  --protocol uwsgi \
  --wsgi-disable-file-wrapper \
  --uid $SERVICE_UID \
  --gid $SERVICE_GID \
  --master \
  --chdir /srv/qwc_service \
  --virtualenv /srv/qwc_service/.venv \
  --mount $SERVICE_MOUNTPOINT=server:app \
  --manage-script-name \
  || failed "Unable to launch uwsgi"
