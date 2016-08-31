#!/bin/bash
# A script to periodically execute maintenance operations using separate .sql files
# $Id: postgresql-maintenance-scripts.sh 48 2012-08-03 18:00:03Z zorlem $

# we execute any scripts that are located in $SQLSCRIPTDIR in the form maint-<instance name>.<database>.sql

PSQL='/usr/bin/psql';
SQLSCRIPTDIR='/mnt/dbbackup/scripts/maintenance/';
PGSQLROOTDIR='/mnt/pgsql'

for sqlfile in $SQLSCRIPTDIR/maint-*.sql; do
	if [ ! -f $sqlfile ]; then
		# the globbing failed (most likely the file does not exist)
		continue;
	fi
	instancedir='';
	basename=`basename "${sqlfile}"`;
	# remove everything before "-" (maint-)
	instance=${basename#*-}
	instance=${instance%.*.sql}
	database=${basename#*-*.}
	database=${database%.sql}
	if [ -d "${PGSQLROOTDIR}/${instance}-data/data/" ]; then
		instancedir="${PGSQLROOTDIR}/${instance}-data/data/"
	elif [ -d "${PGSQLROOTDIR}/${instance}/data/" ]; then
		instancedir="${PGSQLROOTDIR}/${instance}/data/"
	fi
	if [ -n "${instancedir}" ]; then
		# execute the .sql batch file
		$PSQL -h "${instancedir}" -d "${database}" -f "${sqlfile}" >> /var/log/pgsql/maintenance-${instance}.${database}.log
	else
		# ${instance} instance is not running on this server;
		continue;
	fi
done
