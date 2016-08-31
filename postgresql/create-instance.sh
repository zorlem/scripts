#!/bin/bash

PGSQLDIR="/mnt/pgsql"
LOCALONLY=0;

usage() {
	cat << EOF
Creates a new partition, filesystem and initializes a PostgreSQL cluster (instance)
Usage:	$0 [-h] |
	$0 <-i instance_name> <-l>|<-d disk>
Where: 
	-h:	this screen
	-i:	the name of the cluster (instance) - should be max. 16 characters long
	-d:	the disk to use for creating the DB files (eg: /dev/sda). A new partition will be created on the disk
	-l:	create only the top directory and the init script (conflicts with -d)
	-e:	encoding of the cluster
EOF
exit 1;
}

toupper() {
	local char="$*"
	out=$(echo $char | tr [:lower:] [:upper:])
	local retval=$?
	echo "$out"
	unset out char
	return $retval
}

# creates a partition, filesystem, mounts the filesystem and creates the necessary subdirectories
filesystem() {
	local DISK=$1;
	local NAME=$2;
	local PARTITION=${DISK}1;
	local INSTANCEDIR=${PGSQLDIR}/${NAME};
	local XLOGDIR=${PGSQLDIR}/xlog/${NAME};
	local BACKUPDIR=/mnt/dbbackup/${NAME};
	echo -e '0,\n;\n;\n;\n' | sfdisk ${DISK};
	mkfs.ext3  -m 1 -T largefile4 -L $(toupper ${NAME}) ${PARTITION};
	tune2fs -c 60 -i 360 ${PARTITION};
	if [ ! -d "${INSTANCEDIR}" ]; then
		echo "Top level directory ${INSTANCEDIR} does not exist";
		exit 1;
	fi	
	mount "${PARTITION}" "${INSTANCEDIR}";
	touch "${INSTANCEDIR}/is.mounted";
	mkdir "${INSTANCEDIR}/data";
	chown postgres:postgres "${INSTANCEDIR}/data/";
	export LANG=C; su - postgres -c "/usr/bin/initdb --pgdata=/mnt/pgsql/${CLUSTERNAME}/data/ --auth='ident sameuser' -E ${ENCODING} --locale POSIX";
	mkdir ${INSTANCEDIR}/data/pg_log;
	chown postgres:postgres ${INSTANCEDIR}/data/pg_log;
	chmod 700 ${INSTANCEDIR}/data/pg_log/;
	mkdir "${XLOGDIR}" "${BACKUPDIR}"
	chown postgres:postgres "${XLOGDIR}"
	chmod 750 "${XLOGDIR}" 
# transfer needs to be able to read the backups
	chown postgres:transfer "${BACKUPDIR}"
	chmod 2750 "${BACKUPDIR}"
}

# this is not implement
pgsqlconf() {
	sed -i -e "/^#listen_address/alisten_address = $ip" -e "/^#unix_socket_directory/aunix_socket_directory = $socket" -e "s/^max_connections = \([[:digit:]]\+\)/max_connections = $maxconn/" -e "s/^datestyle = .[[:alpha:] ,]\+./datestyle = \'iso, dmy\'/" ${INSTANCEDIR}/data/postgresql.conf
	echo;
}

# creates the top level directory and the init script
localfiles() {
	mkdir "${PGSQLDIR}/${CLUSTERNAME}";
	cp /etc/init.d/postgresql /etc/init.d/postgresql-${CLUSTERNAME}
	echo "PGDATA=${PGSQLDIR}/${CLUSTERNAME}/data" > /etc/sysconfig/pgsql/postgresql-${CLUSTERNAME}
}



if [ $# -eq 0 ]; then
	usage;
	exit 0;
fi

while getopts "lhi:d:e:" option; do
	case $option in
		d) DISK=$OPTARG;;
		i) CLUSTERNAME=$OPTARG;;
		l) LOCALONLY=1;;
		e) ENCODING=$OPTARG;;
		*) usage;;
	esac
done

if [ "${LOCALONLY}" -eq 1 ]; then
	# -d should not be specified
	if [ ! -z "${DISK}" ]; then 
		echo "Local mode and disk specified. Please do not use the -d option together with -l";
		echo;
		usage;
	fi
	# we should have an instance name
	if [ -z "${CLUSTERNAME}" ]; then
		echo "Please specify an instance name with -i";
		echo;
		usage;
	fi
elif [ -z "${DISK}" -o -z "${CLUSTERNAME}" ]; then
	# in non-local mode we need both
	echo "In non-local mode we need both instance (-i) and disk (-d) to be specified";
	echo;
	usage;
fi

if [ ${#CLUSTERNAME} -ge 17 ]; then
	echo "Cluster name \"${CLUSTERNAME}\" is longer than 16 characters (${#CLUSTERNAME})";
	echo;
	usage;
fi

localfiles;
if [ ${LOCALONLY} -eq 0 ]; then
	if [ -z "${ENCODING}" ]; then
		echo "Please specify an encoding for the new cluster using \"-e\"";
		echo;
		usage;
	fi
	filesystem "${DISK}" "${CLUSTERNAME}";	
fi
