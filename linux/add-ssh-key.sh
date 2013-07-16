#!/bin/bash

USER=$1;
KEYFILE=$2;

if [ -z "${USER}" -o -z "${KEYFILE}" ]; then
	echo "Please specify a username and a keyfile";
	echo "Usage: $0 <username> <keyfile>";
	exit 1;
fi

AUTHFILE="/etc/ssh/authorized_keys/${USER}";

if [ ! -e "${KEYFILE}" ]; then
	echo "Error: ${KEYFILE} keyfile doesn't exist";
	exit 1;
fi

if ! getent passwd "${USER}"  1> /dev/null; then
	echo "Error: user ${USER} doesn't exist";
	exit 1;
fi 

if [ ! -e "${AUTHFILE}" ]; then 
	echo "Warning: authorized_keys file ${AUTHFILE} for user ${USER} doesn't exist. Creating it";
	if touch "${AUTHFILE}"; then
		chown "root:${USER}" "${AUTHFILE}";
		chmod 640 "${AUTHFILE}";
	else
		echo "Error: Could not create ${AUTHFILE}";
		exit 1;
	fi
fi

while read -r line; do
	KEYCOMMENT=$(echo "${line}" | awk '{print $NF}');
	if grep -q -F "${line}" "${AUTHFILE}"; then
		# ssh key exists
		echo "$(hostname): key already exists: ${KEYCOMMENT}";
		continue;
	else
		# ssh key not found, add it
		echo "${line}" >> "${AUTHFILE}";
		echo "$(hostname): added key for ${KEYCOMMENT}";
	fi
done < "${KEYFILE}"
