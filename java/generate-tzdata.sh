#!/bin/bash
# gen-java-tzdata.sh - a script that downloads Olson's timezone data, unpacks it
#+and compiles it into Java compatible format using OpenJDK javazic.jar
# Needs wget, tar, and OpenJDK 6 or 7 installed.
#
# tunable parameters
# Generally all capitalized variables (TAR, TZDIR, WGET, etc.) can be modified to match the 
#+values on your system.
#
# If you have a JAVA_HOME environment variable pointing to the JRE directory it will be used by
#+default. Otherwise the one specified bellow will be used. jre/lib/javazic.jar and bin/java should
#+be bellow this directory.
# OpenJDK 6 or 7 (note that this is not for the Sun's JDK as it lacks the necessary javazic.jar. 
JDIR=${JAVA_HOME:=/usr/lib/jvm/default-java/}

# program paths
TAR='/bin/tar'
WGET='/usr/bin/wget'
SED='/bin/sed'

# URL and filename for the Olson TimeZone data. IANA is the official distributor of 
#+the files
TZURL='ftp://ftp.iana.org/tz/'
LASTTZ='tzdata-latest.tar.gz'

# options for the programs
TAROPTIONS='--extract --gzip --file'
WGETOPTIONS='--retr-symlinks --no-verbose --no-clobber'
# timestamping doesn't work for symlinks https://savannah.gnu.org/bugs/index.php?20522
#WGETOPTIONS='--timestamping --retr-symlinks --no-verbose --no-clobber'

set -o nounset;
set -o errexit; 
set -o pipefail;

readonly -a TIMEZONES=( africa \
                        antarctica \
                        asia \
                        australasia \
                        europe \
                        northamerica \
                        southamerica \
                        etcetera \
                        gmt \
                        backward \
                        systemv \
                        pacificnew \
                        solar87 \
                        solar88 \
                        solar89 \
                        )

function error() {
  local linenumber="$1";
  local errmessage="${2:-'No specific error message defined'}";
  local code="${3:-1}";
  echo "Error on or near line ${linenumber}: ${errmessage}; exiting with status ${code}";
  exit "${code}";
}

function gettzdata() {
# downloads the latest timezone data from eg. iana.org in the current directory
  local url="$1"
  echo "Downloading the latest TZ data from $url"
  "$WGET" $WGETOPTIONS "$url"
  if [ "$?" -ne "0" ]; then
    cleanup
    error $LINENO "Failed downloading the latest TZ data from $url"
  fi
}

function unpacktz() {
  local tzarchive="$1"
  if ! [ -d "$TZDIR" ]; then
    mkdir "$TZDIR"
  fi
  if [ -e "$tzarchive" ]; then
    echo "Unpacking $tzarchive to $TZDIR..."
    "$TAR" $TAROPTIONS "$tzarchive" -C "$TZDIR"
    if [ "$?" -ne "0" ]; then
      error $LINENO "Failed unpacking $tzarchive in $TZDIR."
    fi
  else
    error $LINENO "$tzarchive not found, unable to unpack"
  fi
}

function getversion() {
# a function to find out the version of the downloaded TZ data by checking the VERSION 
#+variable in the tzdata Makefile.
#
# http://www.iana.org/time-zones/repository/tz-link.html: Each version is a four-digit year 
#+followed by lower-case letters (a through z, then za through zz, then zza through zzz, and so on). 
  local tzdir="$1"
  # carefully using a global var :(
  version=$("$SED" -ne '/^VERSION=/{s/VERSION=[[:space:]]\+\([[:digit:]]\{4\}[[:alpha:]]\+\)$/\1/;p}' "$tzdir/Makefile")
  if [ -z "$version" ]; then
    error $LINENO "Could not determine the version of the downloaded tzdata package. Maybe the format has changed?"
  fi
}

creategmt() {
  local tzdir="$1"
  cat >> $tzdir/gmt <<EOF_MARKER
#
# Copyright 2000-2005 Sun Microsystems, Inc.  All Rights Reserved.
# DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
#
# This code is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 2 only, as
# published by the Free Software Foundation.  Sun designates this
# particular file as subject to the "Classpath" exception as provided
# by Sun in the LICENSE file that accompanied this code.
#
# This code is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# version 2 for more details (a copy is included in the LICENSE file that
# accompanied this code).
#
# You should have received a copy of the GNU General Public License version
# 2 along with this work; if not, write to the Free Software Foundation,
# Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Please contact Sun Microsystems, Inc., 4150 Network Circle, Santa Clara,
# CA 95054 USA or visit www.sun.com if you need additional information or
# have any questions.
#

# Zone NAME            GMTOFF  RULES   FORMAT  [UNTIL]
Zone   GMT             0:00    -       GMT
EOF_MARKER
}

function zic() {
  local destdir="$1"
  if [ -d "$PWD/zi-$version" ]; then
    cleanup
    error $LINENO "$PWD/zi-$version already exists. Please move it away first"
  fi
  echo "Compiling Olson TZ data to Java TZ format..."
  "${JDIR}/bin/java" -jar "${JDIR}/jre/lib/javazic.jar" -V "$version" -d "$destdir" "${TZFILES[@]}"
  if [ "$?" -eq "0" ]; then
    mv "$destdir" "$PWD/zi-$version"
    echo "The compilation was successful. The new timezone data is available in $PWD/zi-$version."
    echo "This directory should _replace_ the timezone data directory provided by Oracle and"
    echo "should be placed in Oracles's JRE/JDK directory (usually \"\$JAVA_HOME/jre/lib/zi\"), "
    echo "while the JVM is not running."
  else
    error $LINENO "TimeZone data compilation failed. Leaving temp files behind for inspection"
  fi
}

trap 'error ${LINENO}' ERR

cleanup() {
  rm -r -f "$tztmp"
}


tztmp=$(mktemp -d tzjava-update.XXXXXXX);
if ! [ -d "$tztmp" ]; then
  error $LINENO "Error creating temporary directory $tztmp";
fi

TZDIR="$tztmp/tzdata"
TZGENJAVA="$tztmp/tzdata-java"

# prepend $TZDIR to the list of the timezones
readonly -a TZFILES=( "${TIMEZONES[@]/#/$TZDIR/}" )

if ! [ -f "$LASTTZ" ]; then 
  gettzdata "$TZURL/$LASTTZ"
else
  echo "Found existing TZ data file in $LASTTZ. Not downloading it again."
fi
unpacktz "$LASTTZ"
getversion "$TZDIR"
if ! [ -e "$TZDIR/creategmt" ]; then
  creategmt $TZDIR
fi
zic $TZGENJAVA
cleanup
