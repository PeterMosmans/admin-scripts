#!/usr/bin/env bash

# wordpress_backup - Backs up Wordpress sites
#
# Copyright (C) 2014 Peter Mosmans <support@go-forward.net>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

# TODO: backup all sites
#       list all sites in main root
#       create detection for existence of main web directory


NAME="wordpress_backup"

# input variables
sitename=$1
mainweb=/var/www

# logging and verboseness
declare NOLOGFILE=-1
declare QUIET=1
declare STDOUT=2
declare VERBOSE=4
declare LOGFILE=8
declare RAWLOGS=16
declare SEPARATELOGS=32

# colours
declare NONEWLINE=1
declare -c BLUE='\E[1;49;96m' LIGHTBLUE='\E[2;49;96m'
declare -c RED='\E[1;49;31m' LIGHTRED='\E[2;49;31m'
declare -c GREEN='\E[1;49;32m' LIGHTGREEN='\E[2;49;32m'

# defaults
declare -i loglevel=$STDOUT

cleanup() {
    rm -f $tempfile
}

main() {
    local webroot=$1

    if [[ "$#" -lt 1 ]]; then
        usage
        exit 0
    fi

    local website=$(basename ${webroot})
    # check if the webroot is absolute or relative
    [[ ! $webroot =~ ^/ ]] && webroot=${mainweb}/$webroot
    if [ ! -d ${webroot} ]; then
        echo "ERROR: could not find ${webroot}"
        exit 1
    fi

    configfile=${webroot}/wp-config.php
    if [[ ! -s "$configfile" ]]; then
        echo "could not open $configfile"
        exit 1
    fi

    backupfile=/tmp/${website}.zip
    tempfile=/tmp/${website}.sql
    trap cleanup EXIT QUIT

    umask 177
    database=$(awk -F "'" '/DB_NAME/{print $4}' $configfile)
    username=$(awk -F "'" '/DB_USER/{print $4}' $configfile)
    password=$(awk -F "'" '/DB_PASSWORD/{print $4}' $configfile)
    echo "dumping database ${database}..."
    mysqldump --create-options -u$username --password=$password $database > ${tempfile}
    if [ $? -ne 0 ]; then
        echo "ERROR: Could not dump database to /tmp/${sitename}.sql..."
        exit 1
    fi
    rm -r $backupfile
    echo "zipping ${webroot}..."
    pushd ${webroot} &>/dev/null
    zip -r9 $backupfile * 1>/dev/null
    popd &> /dev/null
    echo "adding SQL script to ${backupfile}..."
    zip -m $backupfile ${tempfile} 1>/dev/null
    prettyprint "done, backup resides at ${backupfile}" $GREEN
}

usage () {
    echo "usage: $0 website [backupfile]"
    echo "          website can be relative from main web directory (${mainweb}), or absolute"
    echo "          default name of backupfile is /tmp/website.zip"
    echo ""
    if [ -d ${mainweb} ]; then
        echo " current websites (directories) in ${mainweb}:"
        pushd ${mainweb} &> /dev/null
        ls -d */
        popd  &> /dev/null
    else
        echo "NOTE: ${mainweb} doesn't exist locally, so use an absolute path"
    fi
}

prettyprint() {
    (($loglevel&$QUIET)) && return
    [[ -z $nocolor ]] && echo -ne $2
    if [[ "$3" == "$NONEWLINE" ]]; then
        echo -n "$1"
    else
        echo "$1"
    fi
    [[ -z $nocolor ]] && tput sgr0
}

main "$@"
