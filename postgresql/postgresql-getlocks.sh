#!/bin/bash
# This script gets a list of locked objects
# $Id: postgresql-getlocks.sh 47 2012-08-03 13:24:59Z zorlem $

umask 027
# skip lock files, look only for sockets
for i in /mnt/pgsql/*/data/.s.PGSQL.*[0-9]; do
# remove socket name
	dir=${i%.s.PGSQL*};
# remove /data/.s.PGSQL* (and optionally -data/data/.s.PGSQL* if exists)
	service=${i%%?data/*s.PGSQL.*}
# remove /mnt/pgsql/
	service=${service#/mnt/pgsql/}
	/usr/bin/psql -A -t -q -U postgres -h "${dir}" -f /mnt/dbbackup/scripts/getlocks.sql >> "/var/log/pgsql/locks-${service}.log";
done
