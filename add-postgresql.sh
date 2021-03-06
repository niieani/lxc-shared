#!/bin/bash

CURDIR="$( cd `dirname "${BASH_SOURCE[0]}"` && pwd )"
source $CURDIR/functions.sh
askbreak "Really?"

apt-get install -y libpq-dev libpq5
echo 'deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main' > /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add -
apt-get update
apt-get -y upgrade
apt-get -y -t $DISTRO install postgresql-common
apt-get install postgresql-9.2
apt-get -y autoremove
mkdir -p $DIR/run/postgresql
chmod 42775 $DIR/run/postgresql
chown postgres.postgres $DIR/run/postgres
echo "add password with \password root, exit with \quit"
sudo -u postgres createuser --superuser root
sudo -u postgres psql

set_installed postgresql norun
