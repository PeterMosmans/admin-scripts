#!/usr/bin/env bash

# wordpress_upgrade - Upgrades existing Wordpress installation
#
# Copyright (C) 2013-2014 Peter Mosmans <support@go-forward.net>
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


# TODO parametrization of sitename and full path

NAME=wordpress_update

# constants / defaults
websource="https://wordpress.org/latest.tar.gz"
mainweb=/var/www

main() {
    local webroot=$1
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

    echo "downloading latest version from ${websource}"
    wget -NqO /tmp/wordpress.tar.gz --unlink ${websource}
    if [ $? -ne 0 ]; then
        echo "ERROR while downloading latest version..."
        exit 1
    fi

    echo removing previous unpacked files
    rm -rf /tmp/wordpress 1>/dev/null
    # mkdir /tmp/wordpress
    echo unpacking files
    tar -zxUvf /tmp/wordpress.tar.gz -C /tmp 1>/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR while unpacking latest version..."
        exit 1
    fi
    echo "removing current system files"
    rm -rf $sitepath/wp-includes 1>/dev/null || echo could not remove includes
    rm -rf $sitepath/wp-admin 1>/dev/null || echo could not remove admin
    echo " copying new files"
    cp -rf --preserve=timestamps /tmp/wordpress/* ${webroot}/ 1>/dev/null
    echo " done, please visit ${webroot}/wp-admin/ in your browser"
}

usage() {
    echo "Updates Wordpress installation"
    echo ""
    echo "usage: $0 website"
    echo ""
    echo "          website can be relative from main web directory (${mainweb}), or absolute"
}

main "$@"
