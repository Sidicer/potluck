#!/bin/sh

# shellcheck disable=SC1091
. /root/.env.cook

set -e
# shellcheck disable=SC3040
set -o pipefail

export PATH=/usr/local/bin:$PATH

SCRIPT=$(readlink -f "$0")
TEMPLATEPATH=$(dirname "$SCRIPT")/../templates

# Fix www group memberships so it works with fuse mounted directories
pw addgroup -n newwww -g 1001
pw moduser www -u 1001 -G 80,0,1001

# set perms on /usr/local/www/nextcloud/*
chown -R www:www /usr/local/www/nextcloud

# create a nextcloud log file
# this needs to be configured in nextcloud config.php in copy-in file
touch /var/log/nginx/nextcloud.log
chown www:www /var/log/nginx/nextcloud.log

# manually create php log and set owner
touch /var/log/nginx/php.scripts.log
chown www:www /var/log/nginx/php.scripts.log

# check for .ocdata in DATADIR
# if using S3 with no mount-in this should set it up in the default DATADIR
# /usr/local/nginx/nextcloud/data
if [ ! -f "${DATADIR}/.ocdata" ]; then
   touch "${DATADIR}/.ocdata"
   chown www:www "${DATADIR}/.ocdata"
fi

# set perms on DATADIR
chown -R www:www "${DATADIR}"

# configure self-signed certificates for libcurl, mostly used for minio with self-signed certificates
# nextcloud source needs patching to work with self-signed certificates too
if [ -n "${SELFSIGNHOST}" ]; then
    echo "" |/usr/bin/openssl s_client -showcerts -connect "${SELFSIGNHOST}" |/usr/bin/openssl x509 -outform PEM > /tmp/cert.pem
    if [ -f /tmp/cert.pem ]; then
        cat /tmp/cert.pem >> /usr/local/share/certs/ca-root-nss.crt
        echo "openssl.cafile=/usr/local/share/certs/ca-root-nss.crt" >> /usr/local/etc/php/99-custom.ini
        cat /tmp/cert.pem >> /usr/local/www/nextcloud/resources/config/ca-bundle.crt
    fi
    # Patch nextcloud source for self-signed certificates with S3
    if [ -f /usr/local/www/nextcloud/lib/private/Files/ObjectStore/S3ObjectTrait.php ] && [ -f "$TEMPLATEPATH/S3ObjectTrait.patch" ]; then
        # make sure we haven't already applied the patch
        checknotapplied=$(grep -c verify_peer_name /usr/local/www/nextcloud/lib/private/Files/ObjectStore/S3ObjectTrait.php)
        if [ "${checknotapplied}" -eq 0 ]; then
            # check the patch will apply cleanly
            # shellcheck disable=SC2008
            testpatch=$(patch --check -i /root/S3ObjectTrait.patch /usr/local/www/nextcloud/lib/private/Files/ObjectStore/S3ObjectTrait.php | echo "$?")
            if [ "${testpatch}" -eq 0 ]; then
                # apply the patch
                patch -i "$TEMPLATEPATH/S3ObjectTrait.patch" /usr/local/www/nextcloud/lib/private/Files/ObjectStore/S3ObjectTrait.php
            fi
        fi
    fi
fi

# Configure NGINX
cp -f "$TEMPLATEPATH/nginx.conf" /usr/local/etc/nginx/nginx.conf

# setup cronjob
echo "*/15  *  *  *  *  www  /usr/local/bin/php -f /usr/local/www/nextcloud/cron.php" >> /etc/crontab