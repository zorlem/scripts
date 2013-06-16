#!/bin/bash

# Uncomment these if the connection requires a username, password, hostname, etc. (eg. not configured in ~/.my.cnf)
# MYSQLUSER="username"
# MYSQLPASS="password"
# MYSQLHOST="host"
# MYSQLSOCKET="/var/lib/mysql/mysql.sock"

MYSQLCOMMAND="mysql"
if [ -n "${MYSQLUSER}" ]; then
  MYSQLCOMMAND="${MYSQLCOMMAND} -u ${MYSQLUSER}"
fi

if [ -n "${MYSQLPASS}" ]; then
  MYSQLCOMMAND="${MYSQLCOMMAND} -p${MYSQLPASS}"
fi

if [ -n "${MYSQLHOST}" ]; then
  MYSQLCOMMAND="${MYSQLCOMMAND} -h${MYSQLHOST}"
fi

if [ -n "${MYSQLSOCK}" ]; then
  MYSQLCOMMAND="${MYSQLCOMMAND} -S${MYSQLSOCK}"
fi

WAITTIME="10";

if [ "$#" -lt 2 ]; then
	echo "Usage: $0 <connect string> <search string>";
	exit 128;
fi

PROGRESS="Progress: (S=skipping, _=Waiting $WAITTIME)\\n"

connect="$1";
searchstring="$2";

echo -ne "${PROGRESS}"
while(true); do
        SLAVESTATUS=`${MYSQLCOMMAND} ${connect} -B -e "show slave status\G"`
	if [ -z "${SLAVESTATUS}" ]; then
		echo "Could not obtain the status of the slave, check your connect string";
		exit 128;
	fi
        echo $SLAVESTATUS | grep -q -E "${searchstring}"
        if [ "$?" -eq "0" ]; then
		PROGRESS='S';
		echo -ne "${PROGRESS}"
                ${MYSQLCOMMAND} $connect -B -e "SET GLOBAL SQL_SLAVE_SKIP_COUNTER=1; start slave;";
		sleep 1;
        else
                SECONDS=`echo "$SLAVESTATUS" | awk '/Seconds_Behind_Master/{if($2 == "NULL") {print -1} else {print $2}}'`
		# We map "NULL" to -1
                if [ "${SECONDS}" -lt "0" ]; then
                        echo "The replication is stopped, but the search string $searchstring was not found";
                        echo "Last_Error at the moment is:"
                        echo "$SLAVESTATUS" | grep 'Last_Error:'
                        exit 1;
                elif [ "${SECONDS}" -lt "10" ]; then
                        echo "Replication lag is ${SECONDS} seconds, which is less than 10 seconds, everything is fine, probably";
			echo "$SLAVESTATUS" | grep -E 'Last_error|Seconds_Behind_Master'
                        exit 0;
                else 
                        # the replication is still catching up, wait a little bit longer and retry
			PROGRESS="_";
			echo -ne "${PROGRESS}";
                        sleep "${WAITTIME}";
                fi
        fi
done
