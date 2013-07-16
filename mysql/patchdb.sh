#!/bin/bash
# a script for keeping a DB up to date with the help of a revisions table. It 
# extracts the last revision from the DB and then applies all files that it 
# finds in ${SQLUPDATEDIR} matching the pattern r[0-9]+.sql. The script orders 
# the updates by filename.

declare -a patchlist;

function usage {
	echo "Usage: $0 <dbname> <sqlfilesdir> <lastcoderev>";
	exit 1;
}

function getlastappliedrev {
	lastrev=$(mysql -D "${DB}" --batch --skip-column-names -e 'select max(revision) from revisions');
}

function getpatchlist {
	i=0;
	for file in `ls -1 ${SQLFILESDIR}/r[0-9][0-9][0-9][0-9][0-9].sql | sort -n`; do
		patchlist[i++]=$file;
	done	       
}

function applypatch {
	patchfile="${1}";
	mysql --one-database --default-character-set=utf8 "${DB}" < "${patchfile}" > "${patchfile}.log"
}

if [[ -z "$1" ]]; then
	usage;
fi

if [[ -z "$2" ]]; then
	usage;
fi

if [[ -z "$3" ]]; then
	usage;
fi

if [[ "${1}" =~ [^a-z0-9_-] ]]; then
	echo "invalid symbols detected in the the DB you have specified: ${1}. Valid symbols are [a-z0-9_-]";
	exit 1;
else
	DB="${1}";
fi

if [[ "${2}" =~ [^a-z0-9_/.-] ]]; then
	echo "invalid symbols detected in the the sqlfilesdir you have specified: ${2}. Valid symbols are [a-z0-9_/.-]";
	exit 1;
else
	SQLFILESDIR="${2}";
fi

if [[ "${3}" =~ [^0-9] ]]; then
	echo "invalid symbols detected in the the sqlfilesdir you have specified: ${2}. Valid symbols are [a-z0-9_/.-]";
	exit 1;
else
	CODEREV="${3}";
fi



getlastappliedrev;
getpatchlist;
for patchfile in ${patchlist[@]}; do
	patchrev=`basename $patchfile`;	
	patchrev=$(echo $patchrev | sed -e 's/^r0*\([0-9]*\).sql$/\1/');
	if [[ "${patchrev}" -gt "${lastrev}" && "${patchrev}" -le "${CODEREV}" ]]; then
		echo "Applying SQL patch: ${patchfile}";
		applypatch "${patchfile}";	
		if [[ "$?" -ne 0 ]]; then
			echo "Error: SQL patch ${patchfile} did not apply correctly. Aborting";
			exit 1;
		fi
	fi
done

