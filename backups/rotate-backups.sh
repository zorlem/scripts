#!/bin/bash

CONFIG=$1;
if [ -z "${CONFIG}" ]; then
	echo -e "Please specify a backup config file to read from.\nUsage: \t$0 <backup config file>";
	exit 1;
fi

if [ ! -r "${CONFIG}" ]; then
	echo "Can not open ${CONFIG} for reading";
	exit 1;
fi

source $CONFIG;

if [ -z "${PDEST}" -o -z "${INSTANCE}" ]; then
	echo "Required variables \$PDEST or \$INSTANCE are not defined in the config file ${CONFIG}";
	exit 1;
else
	BACKUPDIR="${PDEST}/${INSTANCE}";
fi

umask 077
yesterday=`date -d '1 days ago' --rfc-3339=date`

# move last backup to its place
if [ -d "${BACKUPDIR}/new" ]; then
	lastdate=`stat -c @%Y "${BACKUPDIR}/new"`;
	lastdate=`date -d "${lastdate}" --rfc-3339=date`;
	echo	mv "${BACKUPDIR}/new" "${BACKUPDIR}/${lastdate}"
fi

exit
if ! mkdir "${BACKUPDIR}/new"; then
	echo "Error: Could not create ${BACKUPDIR}/new";
	exit 1;
fi

# find fresh files
find "${BACKUPDIR}/" -maxdepth 1 -daystart -type f -mtime 0 -execdir echo mv -t "${BACKUPDIR}/new/" {} +;
# clean old stale dirs
find "${BACKUPDIR}/" -depth -type d -empty -delete;
exit 0;
