#!/bin/sh

# shellcheck disable=SC1091
. /root/.env.cook

set -e
# shellcheck disable=SC3040
set -o pipefail

SCRIPT=$(readlink -f "$0")
TEMPLATEPATH=$(dirname "$SCRIPT")/../templates

mkdir -p /usr/local/etc/consul-template.d

# shellcheck disable=SC3003
# safe(r) separator for sed
sep=$'\001'

TOKEN=$(/bin/cat /mnt/vaultcerts/unwrapped.token)
cp "$TEMPLATEPATH/consul-template.hcl.in" \
  /usr/local/etc/consul-template.d/consul-template.hcl
chmod 600 \
  /usr/local/etc/consul-template.d/consul-template.hcl
echo "s${sep}%%token%%${sep}$TOKEN${sep}" | sed -i '' -f - \
  /usr/local/etc/consul-template.d/consul-template.hcl

if [ "$SERVICETAG" = "backup_node" ]; then
    SOB_PREFIX=backup-node
else
    SOB_PREFIX=standby-leader
fi

for name in vault consul patroni metrics; do
    < "$TEMPLATEPATH/$name.tpl.in" \
      sed "s${sep}%%ip%%${sep}$IP${sep}g" | \
      sed "s${sep}%%nodename%%${sep}$NODENAME${sep}g" | \
      sed "s${sep}%%datacenter%%${sep}$DATACENTER${sep}g" | \
      sed "s${sep}%%standby_or_backup_prefix%%${sep}$SOB_PREFIX${sep}g" \
      > "/mnt/templates/$name.tpl"
done

mkdir -p /mnt/metricscerts

sysrc consul_template_syslog_output_enable=YES
sysrc consul_template_syslog_priority="warn"
service consul-template enable
