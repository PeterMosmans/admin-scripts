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
# TODO: better error handling
# TODO: create backup

NAME="wordpress_update_plugins"

# constants
websource="https://downloads.wordpress.org/plugin"
pluginpath="wp-content/plugins"

main() {
    initialize_globals
    parse_options "$@"
    local fullpath=${webroot}/${pluginpath}
    if [ ! -d ${webroot} ]; then
        echo "ERROR: could not find ${webroot}"
        exit 1
    fi

    ${do_all} &&  update_all_plugins "${fullpath}"
    ${do_list} && list_plugins "${fullpath}"
    ${do_update} && update_plugin "${fullpath}" $plugin $version
}

initialize_globals() {
     do_all=false
     do_list=false
     do_update=false
     dry_run=
     verbose=1>/dev/null
 }

update_all_plugins() {
    echo updating all plugins...
    local plugindir=$1
    pushd ${plugindir} >&/dev/null
    for plugin in $(ls -d */|sed -e "s/\/$//"); do
        echo $plugin
        update_plugin ${plugindir} ${plugin}
    done
    popd >&/dev/null
 }
parse_options() {
    if ! options=$(getopt -o a,l,n -l all,dry-run,list -- "$@") ; then
        usage
        exit 1
    fi

    eval set -- $options
    if [[ "$#" -le 1 ]]; then
        usage
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--all)
                do_all=true;;
            -l|--list)
                do_list=true;;
            -n|--dry-run)
                dry_run=echo
                verbose=
                ;;
            (--) shift;
                 break;;
            (*)  break;;
        esac
        shift
    done

    if [ -z "$1" ]; then
        echo "ERROR: please specify webroot (eg. /var/www/my.website )"
        exit 1
    fi

    webroot=$1
    if [ ! -z $2 ]; then
        plugin=$2
        do_update=TRUE
    fi
    version=$3
}

list_plugins() {
    local plugindir=$1
    pushd ${plugindir}
    ls -d */
    popd >&/dev/null
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
    ${dry_run} wget --unlink -NqO /tmp/${plugin}.zip ${websource}/${file}.zip
    if [ $? -ne 0 ]; then
        echo "ERROR while downloading version..."
        return 1
    else
        echo "unzipping ${plugin}"
        # -o overwrite (don't ask questions)
        # -u update files and create new ones
        ${dry_run} unzip -ou /tmp/${plugin}.zip -d ${plugindir}
        if [ $? -ne 0 ]; then
            echo "ERROR while unzipping ${plugin}..."
        else
            ${dry_run} chown -R webjail.webjail ${plugindir}/${plugin}
            ${dry_run} rm -f /tmp/${plugin}.zip
        fi
    fi
}

usage() {
    cat << EOF
Updates Wordpress plugins

usage: $0 webroot [OPTION]...  [PLUGINNAME]

Options:
-a, --all       update all plugins
-l, --list      list all installed plugins
-n  --dry-run   don't actually do anything, just show what would be done

EOF
}

main "$@"
