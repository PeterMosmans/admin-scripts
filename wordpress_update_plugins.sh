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
#       update all plugins automatically

NAME="wordpress_update_plugins"

# constants
websource="https://downloads.wordpress.org/plugin"
pluginpath="wp-content/plugins"
mainweb=/var/www

main() {
    local webroot=$1
    local plugin=$2
    local version=$3
    local fullpath=${1}/${pluginpath}
    # check if the webroot is absolute or relative
    [[ ! $webroot =~ ^/ ]] && webroot=${mainweb}/$webroot

    if [[ "$#" -lt 1 ]]; then
        usage
        exit 0
    fi

    if [ ! -d ${webroot} ]; then
        echo "ERROR: could not find ${webroot}"
        exit 1
    fi

    if [ "$#" -eq 1 ]; then
        list_plugins ${webroot}/${pluginpath}
    else
        if [ -d ${fullpath}/$2 ]; then
            echo updating $2
        else
            echo installing $2
        fi
        update_plugin "${webroot}/${pluginpath}" $plugin $version
    fi
}

list_plugins() {
    local plugindir=$1
    ll ${plugindir}
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
        echo "ERROR while downloading latest version..."
        exit 1
    fi
    echo "unzipping ${plugin}"
    # -o overwrite (don't ask questions)
    # -u update files and create new ones
    unzip -ou /tmp/${plugin}.zip -d ${plugindir} 1>/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR while unzipping ${plugin}..."
        exit 1
    fi
    chown -R webjail.webjail ${plugindir}/${plugin} 1>/dev/null
    rm -f /tmp/${plugin}.zip
}

usage() {
    echo "Updates Wordpress plugins"
    echo ""
    echo "usage: $0 website pluginname [version]"
    echo ""
    echo "          website can be relative from main web directory (${mainweb}), or absolute"
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

main "$@"
