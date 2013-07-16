#!/bin/bash

# a short script to get all entries for net.* from /etc/sysctl.conf and print their 
# current values from /proc/sys/net/*


#
# error():
#+ error handling. this function is called either by trapping the ERR signal (raised 
#+ because "errexit" is set or by calling it directly.
# Args:
# $1 the line of code that raised the error
# $2 an optional error message
# $3 an optional error code. The program will exit with this error code.
#
function error {
  local lnumber="$1";
  local msg="${2:-'No specific error message defined'}";
  local code="${3:-1}";
  echo "Error on or near line ${lnumber}: ${msg}; exiting with status ${code}";
  exit "${code}";
}

trap 'error ${LINENO}' ERR;

# 
# usage():
# prints a help message
# Args: none
#
function usage {
  echo "$0: gets remote /proc/sys/net/ values for entries that exist in /etc/sysctl.conf";
  echo;
  echo "Usage: $(basename $0) <ssh connect string>";
  echo;
  echo -e "\t<ssh connect string>: a string like username@hostname to be passed to ssh";
  echo;
}


if [ "$#" -eq "$NO_ARGS" ]; then 
  usage;
  error "${LINENO}" "No options specified" "$OPTERROR";
fi 


# match only net.* lines in sysctl.conf
ssh "$1" "sed -ne '/^net\./{s/\./\//g;s/ = [0-9]\+//;p}' /etc/sysctl.conf  | xargs -i bash -c 'echo -n {}:\ | tr / . ; cat /proc/sys/{}'"
