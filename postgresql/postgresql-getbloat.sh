#!/bin/bash
# this script compiles a list of indexes and their relative bloat index
# $Id: postgresql-getbloat.sh 47 2012-08-03 13:24:59Z zorlem $
NOW=`date +%Y%m%d-%H%M`;
for socket in /mnt/pgsql/*/data/.s*[^k]; 
	do host=`dirname $socket`;
	instance=`echo $host | sed -e 's/[-\/]\?data//g;s/\/mnt\/pgsql\///g'`;
	psql -A -t -l -h $host | cut -d '|' -f 1 | grep -vE 'template|postgres|nagios' | \
	while read db; do
		exec 1>/mnt/dbbackup/scripts/logs/$instance-$db-bloat-`date +%Y%m%d-%H%M`.txt
		echo $instance-$db;
		psql -h $host -d $db -f /mnt/dbbackup/scripts/bloat.sql	
	done;
done
