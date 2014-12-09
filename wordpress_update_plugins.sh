#!/usr/bin/env bash

# wordpress_upgrade_plugins - Upgrades Wordpress plugins
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

# TODO: action for removal of plugin


NAME="wordpress_update_plugins"

# defaults
group="webjail"
mainweb=/var/www
pluginpath="wp-content/plugins"
owner="webjail"
websource="https://downloads.wordpress.org/plugin"

# internal parameters
do_update_all=false
do_list_plugins=false

# main function first, the rest is ordered alphabetically
main() {
    parse_options "$@"
    echo "BETA VERSION - bugs are present and not all features are correctly implemented"
    
    if [[ $do_list_plugins || $do_update_all ]]; then
        local list=$(list_plugins "${fullpath}")
    fi
    
    if $do_list_plugins; then
        if [ -z "$list" ]; then
            echo "could not find any plugins.. is this a valid WordPress installation path ?" >&2
            return
        else
            echo "list of installed plugins in ${fullpath}:"
            echo "${list}"
        fi
    fi
    if $do_update_all; then
        echo "updating all plugins"
        while read plugin; do
            echo updating $plugin
            update_plugin "${fullpath}" $plugin
            if [ $? -ne 0 ]; then
                echo "${plugin} not updated.." >&2
            fi
        done <<< "${list}"
    fi
}

list_plugins() {
    local plugindir=$1
    if [ -d ${plugindir} ]; then
        pushd ${plugindir} &> /dev/null
        ls -d */ 2>/dev/null|sed -e 's/\/$//'
        popd  &> /dev/null
    fi
}

parse_options() {
    # check if any parameters are specified
    if [[ "$#" -lt 1 ]]; then
        usage
        exit 0
    fi
    
    # check if valid options are specified
    if ! options=$(getopt -o :a -l all,list -- "$@") ; then
        usage
        exit 1
    fi

    # make sure that quoted options are treated correctly as one option
    eval set -- $options

    # set basic option if only one parameter (website) is specified
    if [[ "$#" -eq 2 ]] && ! [[ $2 =~ ^- ]]; then
        do_list_plugins=true
    fi

    while [[ -n "$1" ]]; do
        case $1 in
            -a|--all)
                do_update_all=true;;
            --list)
                do_list_plugins=true;;
            (--)
                shift
                break;;
            (-*) echo "$0: unrecognized option $1" >&2;;
        esac
        shift
    done
    
    if [ "$#" -lt 1 ]; then
        echo "ERROR: no webroot specified" >&2
        exit 1
    fi
    
    webroot="$1"

    # check if the webroot is absolute or relative
    [[ ! "${webroot}" =~ ^/ ]] && webroot="${mainweb}/${webroot}"
    
    # check if the specified webroot exists
    if [ ! -d "${webroot}" ]; then
        echo "ERROR: could not find ${webroot}" >&2
        exit 1
    fi

    fullpath="${webroot}/${pluginpath}"
    plugin=$2
    version=$3
}

retrieve_owner() {
    local plugindir=$1
    owner_group="${owner}:${group}"
    if [ -d ${plugindir} ]; then
        owner_group=$(ls -ld ${plugindir}|awk '{printf $3":"$4}')
    fi
}

update_all() {
    local plugindir=$1
    local all_plugins=$(list_plugins $plugindir)
    while read plugin; do
        echo updating $plugin
    done < $(all_plugins)
}

update_plugin() {
    local plugindir=$1
    local plugin=$2
    local version=$3
    if [ ! -z $version ]; then
        echo using specific version number ${version}
        local file=${plugin}.{$version}
    else
        local file=${plugin}
    fi
    echo "downloading ${plugin} from ${websource}"
    wget --unlink -NqO /tmp/${plugin}.zip ${websource}/${file}.zip 1>/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR while downloading latest version" >&2
        return 1
    fi
    echo "unzipping ${plugin}"
    # -o overwrite (don't ask questions)
    # -u update files and create new ones
    unzip -ou /tmp/${plugin}.zip -d ${plugindir} 1>/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR while unzipping ${plugin}..." >&2
        return 1
    fi
    retrieve_owner "${plugindir}"
    echo "changing owner and group to ${owner_group}"
    chown -R "${owner_group}" ${plugindir}/${plugin} 1>/dev/null
    rm -f /tmp/${plugin}.zip
}

usage() {
    echo "Updates Wordpress plugins"
    echo ""
    echo "usage: $0 website pluginname [version]"
    echo ""
    echo "          website can be relative from main web directory (${mainweb}), or absolute"
    echo ""
    echo "Options:"
    echo " -a, --all               update all plugins (except when NO_AUTO_UPDATE flag is found)"
    echo "     --list              list all currently installed plugins"
    echo ""
    echo "BETA VERSION - bugs are present and not all features are correctly implemented"
    
    if [ -d ${mainweb} ]; then
        echo " current websites (directories) in ${mainweb}:"
        pushd ${mainweb} &> /dev/null
        ls -d */|sed -e 's/\/$//'
        popd  &> /dev/null
    else
        echo "NOTE: ${mainweb} doesn't exist locally, so use an absolute path"
    fi
}

main "$@"
