#!/bin/sh

# shellcheck disable=SC1091
if [ -e /root/.env.cook ]; then
    . /root/.env.cook
fi

set -e
# shellcheck disable=SC3040
set -o pipefail

export PATH="/usr/local/bin:$PATH"

SCRIPT=$(readlink -f "$0")
TEMPLATEPATH=$(dirname "$SCRIPT")/../templates
HOSTNAME="$HOSTNAME"
IP="$IP"
# shellcheck disable=SC3003,SC2039
# safe(r) separator for sed
sep=$'\001'

< "$TEMPLATEPATH/httpd.conf.in" \
 sed "s${sep}%%hostname%%${sep}$HOSTNAME${sep}g" | \
 sed "s${sep}%%ip%%${sep}$IP${sep}g" \
> /usr/local/etc/apache24/httpd.conf

service apache24 enable || true
