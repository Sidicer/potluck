#!/bin/sh

# shellcheck disable=SC1091
if [ -e /root/.env.cook ]; then
    . /root/.env.cook
fi

set -e
# shellcheck disable=SC3040
set -o pipefail

export PATH=/usr/local/bin:$PATH

SCRIPT=$(readlink -f "$0")
TEMPLATEPATH=$(dirname "$SCRIPT")/../templates

## start consul config
# make consul configuration directory and set permissions
mkdir -p /usr/local/etc/consul.d
chown consul /usr/local/etc/consul.d
chmod 750 /usr/local/etc/consul.d

# shellcheck disable=SC3003,SC2039
# safe(r) separator for sed
sep=$'\001'

#GOSSIPKEY="$(cat /mnt/consulcerts/gossip.key)"
# GOSSIPKEY is passed in as a variable

# temporary removal HCL consul as not starting
#< "$TEMPLATEPATH/consul-agent.hcl.in" \
#  sed "s${sep}%%datacenter%%${sep}$DATACENTER${sep}g" | \
#  sed "s${sep}%%nodename%%${sep}$NODENAME${sep}g" | \
#  sed "s${sep}%%ip%%${sep}$IP${sep}g" | \
#  sed "s${sep}%%consulservers%%${sep}$FIXCONSULSERVERS${sep}g" \
#  > /usr/local/etc/consul.d/agent.hcl
#
#chmod 600 \
#  /usr/local/etc/consul.d/agent.hcl
#echo "s${sep}%%gossipkey%%${sep}$GOSSIPKEY${sep}" | sed -i '' -f - \
#  /usr/local/etc/consul.d/agent.hcl

# temporary replacement with json config
< "$TEMPLATEPATH/consul-agent.json.in" \
  sed "s${sep}%%datacenter%%${sep}$DATACENTER${sep}g" | \
  sed "s${sep}%%nodename%%${sep}$NODENAME${sep}g" | \
  sed "s${sep}%%ip%%${sep}$IP${sep}g" | \
  sed "s${sep}%%consulservers%%${sep}$FIXCONSULSERVERS${sep}g" \
  > /usr/local/etc/consul.d/agent.json

chmod 600 /usr/local/etc/consul.d/agent.json

echo "s${sep}%%gossipkey%%${sep}$GOSSIPKEY${sep}" | sed -i '' -f - \
  /usr/local/etc/consul.d/agent.json

# set owner and perms on _directory_ /usr/local/etc/consul.d with agent.hcl
chown -R consul:wheel /usr/local/etc/consul.d/

# enable consul
service consul enable || true

# set load parameter for consul config
#sysrc consul_args="-config-file=/usr/local/etc/consul.d/agent.hcl"
sysrc consul_args="-config-file=/usr/local/etc/consul.d/agent.json" || true
sysrc consul_syslog_output_priority="warn" || true
#sysrc consul_datadir="/var/db/consul"
#sysrc consul_group="wheel"

# setup consul logs, might be redundant if not specified in agent.hcl above
mkdir -p /mnt/applog/consul
touch /mnt/applog/consul/consul.log
chown -R consul:wheel /mnt/applog/consul

# place acl-tokens
mkdir -p /var/db/consul
chmod 750 /var/db/consul
#cp -a /mnt/consulcerts/acl-tokens.json /var/db/consul/.
chown -R consul:consul /var/db/consul
