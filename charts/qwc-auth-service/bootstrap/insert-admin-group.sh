#!/usr/bin/env sh

echo "SELECT g.id FROM qwc_config.groups g WHERE \"name\"='{{ .Values.authOidc.adminGroupName }}'" \
  | psql service=qwc_configdb -t -A -v ON_ERROR_STOP=1 >/tmp/test_count.tmp

if [ -z "$(cat /tmp/test_count.tmp)" ]; then
  echo "INSERT INTO qwc_config.groups (\"name\", description) VALUES('{{ .Values.authOidc.adminGroupName }}', '{{ .Release.Name }}')" \
    | psql service=qwc_configdb -t -A -v ON_ERROR_STOP=1 >/tmp/test_count.tmp
  echo "Group '{{ .Values.authOidc.adminGroupName }}' added!"
else
  echo "Group '{{ .Values.authOidc.adminGroupName }}' already set!"
fi

echo "SELECT gr.group_id FROM qwc_config.groups_roles gr, qwc_config.roles r, qwc_config.groups g WHERE r.\"name\"='admin' AND g.\"name\"='{{ .Values.authOidc.adminGroupName }}' AND gr.group_id=g.id AND gr.role_id=r.id" \
  | psql service=qwc_configdb -t -A -v ON_ERROR_STOP=1 >/tmp/test_count.tmp

if [ -z "$(cat /tmp/test_count.tmp)" ]; then
  echo "INSERT INTO qwc_config.groups_roles (group_id, role_id) SELECT g.id, r.id FROM qwc_config.roles r, qwc_config.groups g WHERE r.\"name\"='admin' AND g.\"name\"='{{ .Values.authOidc.adminGroupName }}'" \
    | psql service=qwc_configdb -t -A -v ON_ERROR_STOP=1 >/tmp/test_count.tmp
  echo "Role 'admin' added to group '{{ .Values.authOidc.adminGroupName }}'!"
else
  echo "Role 'admin' already set to group '{{ .Values.authOidc.adminGroupName }}'!"
fi
