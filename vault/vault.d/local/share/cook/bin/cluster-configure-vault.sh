#!/bin/sh

# shellcheck disable=SC1091
. /root/.env.cook

set -e
# shellcheck disable=SC3040
set -o pipefail

SCRIPT=$(readlink -f "$0")
TEMPLATEPATH=$(dirname "$SCRIPT")/../templates

# shellcheck disable=SC3003
# safe(r) separator for sed
sep=$'\001'

< "$TEMPLATEPATH/cluster-vault-bootstrap.hcl.in" \
  sed "s${sep}%%ip%%${sep}$IP${sep}g" \
  | sed "s${sep}%%nodename%%${sep}$NODENAME${sep}g" \
  | sed "s${sep}%%unsealip%%${sep}$UNSEALIP${sep}g" \
  > /usr/local/etc/vault-bootstrap.hcl

< "$TEMPLATEPATH/cluster-vault.hcl.in" \
  sed "s${sep}%%ip%%${sep}$IP${sep}g" \
  | sed "s${sep}%%nodename%%${sep}$NODENAME${sep}g" \
  | sed "s${sep}%%unsealip%%${sep}$UNSEALIP${sep}g" \
  > /usr/local/etc/vault.hcl

# Set permission for vault.hcl, so that vault can read it
chown vault:wheel /usr/local/etc/vault.hcl
chown vault:wheel /usr/local/etc/vault-bootstrap.hcl
chmod 600 /usr/local/etc/vault.hcl
chmod 600 /usr/local/etc/vault-bootstrap.hcl

# set permissions on /mnt for vault data
chown -R vault:wheel /mnt/vault /mnt/unsealcerts /mnt/certs

# setup rc.conf entries
# we do not set vault_user=vault because vault will not start
service vault enable
sysrc vault_login_class=root
sysrc vault_syslog_output_enable="YES"
sysrc vault_syslog_output_priority="warn"
sysrc vault_config=/usr/local/etc/vault-bootstrap.hcl

rm -f /root/.vault-token

TOKEN=$(/bin/cat /mnt/unsealcerts/unwrapped.token)
(
    umask 177
    echo "s${sep}%%vaultunsealtoken%%${sep}$TOKEN${sep}g" |
      /usr/bin/sed -f - -i '' /usr/local/etc/vault.hcl
    echo "s${sep}%%vaultunsealtoken%%${sep}$TOKEN${sep}g" |
      /usr/bin/sed -f - -i '' /usr/local/etc/vault-bootstrap.hcl
)

echo "Cloning consul-template rc scripts"
cp -a /usr/local/etc/rc.d/consul-template \
  /usr/local/etc/rc.d/consul-template-unseal
sed -i '' 's/consul_template/consul_template_unseal/g' \
  /usr/local/etc/rc.d/consul-template-unseal
sed -i '' 's/consul-template/consul-template-unseal/g' \
  /usr/local/etc/rc.d/consul-template-unseal
ln -s /usr/local/bin/consul-template \
  /usr/local/bin/consul-template-unseal

echo "Writing consul-template-unseal config"
mkdir -p /usr/local/etc/consul-template-unseal.d

< "$TEMPLATEPATH/cluster-consul-template-unseal.hcl.in" \
  sed "s${sep}%%unsealip%%${sep}$UNSEALIP${sep}g" \
  > /usr/local/etc/consul-template-unseal.d/consul-template-unseal.hcl
chmod 600 \
  /usr/local/etc/consul-template-unseal.d/consul-template-unseal.hcl
echo "s${sep}%%token%%${sep}$TOKEN${sep}" | sed -i '' -f - \
  /usr/local/etc/consul-template-unseal.d/consul-template-unseal.hcl

< "$TEMPLATEPATH/cluster-unseal-client.crt.tpl.in" \
  sed "s${sep}%%ip%%${sep}$IP${sep}g" | \
  sed "s${sep}%%nodename%%${sep}$NODENAME${sep}g" | \
  sed "s${sep}%%attl%%${sep}$ATTL${sep}g" \
  > /mnt/templates/unseal-client.crt.tpl

< "$TEMPLATEPATH/cluster-unseal-client.key.tpl.in" \
  sed "s${sep}%%ip%%${sep}$IP${sep}g" | \
  sed "s${sep}%%nodename%%${sep}$NODENAME${sep}g" | \
  sed "s${sep}%%attl%%${sep}$ATTL${sep}g" \
  > /mnt/templates/unseal-client.key.tpl

< "$TEMPLATEPATH/cluster-unseal-ca.crt.tpl.in" \
  sed "s${sep}%%ip%%${sep}$IP${sep}g" | \
  sed "s${sep}%%nodename%%${sep}$NODENAME${sep}g" | \
  sed "s${sep}%%attl%%${sep}$ATTL${sep}g" \
  > /mnt/templates/unseal-ca.crt.tpl

echo "Enabling and starting consul-template-unseal"
sysrc consul_template_unseal_syslog_output_enable=YES
service consul-template-unseal enable
