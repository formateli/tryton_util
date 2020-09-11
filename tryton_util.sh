#!/bin/bash

# tryton_util.sh v1.0
#
# A simple bash script for tryton tasks.
#
# Copyright (C) 2018-2020 Fredy Ramirez - <http://www.formateli.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


BASE_DIR="$PWD"
DOWNLOAD_SERVER="https://downloads-cdn.tryton.org"


show_help(){
    echo $"Usage: $0 { help | init | run | test | download | download_sao | update_module | set_password | ulink}"
    exit
}

create_dir(){
    if [ ! -d "$1" ]; then
        mkdir "$1"
    fi
}

verify_file(){
    if [ ! -f "$1" ]; then
        echo "ERROR: File $1 not found."
        exit
    fi
}

verify_dir(){
    if [ ! -d "$1" ]; then
        echo "ERROR: Directory $1 not found."
        exit
    fi
}

download_tar(){
    if [ ! -d "$2/$1" ]; then
        echo " Downloading $1 FROM $DOWNLOAD_SERVER..."
        wget "$DOWNLOAD_SERVER/$TRYTOND_VERSION/$1.$3"
        mv ./$1.$3 $2
        echo " Uncompressing..."
        tar -xzvf $2/$1.$3 -C $2
        echo " deleting $3..."
        rm -f $2/$1.$3
    fi
}

SYSTEM="???"
ACTION=""
DATABASE=""
MODULE=""
ALL=0
LOG=0

while getopts s:a:d:m:xl option
do
case "${option}" in
        s) SYSTEM=${OPTARG};;
        a) ACTION=${OPTARG};;
        d) DATABASE=${OPTARG};;
        m) MODULE=${OPTARG};;
        x) ALL=1;;
        l) LOG=1;;
    esac
done

if [ "$ACTION" == "" ]; then
    show_help
fi

BASE_DIR="$PWD/$SYSTEM"
verify_dir $BASE_DIR
verify_file $BASE_DIR/config.sh

# Get TRYTOND_VERSION, TRYTOND_REVISION, SAO_REVISION,
# PYTHON, DEVELOP_PATH, REPOSITORY_PATH, MODULES
source $BASE_DIR/config.sh

verify_dir $REPOSITORY_PATH
REPOSITORY_PATH="$REPOSITORY_PATH/$TRYTOND_VERSION"
create_dir "$REPOSITORY_PATH"
create_dir "$REPOSITORY_PATH/modules"
create_dir "$REPOSITORY_PATH/gui"

TRYTOND="$REPOSITORY_PATH/trytond-$TRYTOND_VERSION.$TRYTOND_REVISION"

echo "Running tool for module $MODULE"

get_name_rev(){
    INDEX=`expr index "$1" " "`
    NAME_INDEX=$(($INDEX - 1))
    EXP=$1
    NM=${EXP:0:$NAME_INDEX}
    RV=${EXP:$INDEX}
    echo "$NM $RV"
}

link_modules() {
    ulink
    echo "Linking modules..."
    count=0
    while [ "x${MODULES[count]}" != "x" ]
    do
        read NAME REV < <(get_name_rev "${MODULES[count]}")
        if [[ $REV == ?(-)+([0-9]) ]]; then
            DIRX="$REPOSITORY_PATH/modules/trytond_$NAME-$TRYTOND_VERSION.$REV"
        else
            DIRX="$DEVELOP_PATH/$REV"
        fi

        verify_dir $DIRX
        if [ ! -d "$TRYTOND/trytond/modules/$NAME" ]; then
            echo " $NAME"
            ln -s $DIRX "$TRYTOND/trytond/modules/$NAME"
        fi
        count=$(( $count + 1 ))
    done
}

run() {
    verify_file "$BASE_DIR/trytond.conf"
    link_modules
    if [ "$LOG" == 1 ]; then
        $PYTHON $TRYTOND/bin/trytond -v -c $BASE_DIR/trytond.conf --logconf=$BASE_DIR/log.conf
    else
        $PYTHON $TRYTOND/bin/trytond -v -c $BASE_DIR/trytond.conf
    fi
}

run_cron() {
    verify_file "$BASE_DIR/trytond.conf"
    $PYTHON $TRYTOND/bin/trytond-cron -v -c $BASE_DIR/trytond.conf -d $DATABASE
}

test() {
    export PYTHONPATH=$TRYTOND
    link_modules
    $PYTHON $TRYTOND/trytond/tests/run-tests.py -v -f -m $MODULE
}

init() {
    verify_file "$BASE_DIR/trytond.conf"
    link_modules
    $PYTHON $TRYTOND/bin/trytond-admin -v -c $BASE_DIR/trytond.conf -d $DATABASE --all
}

set_password(){
    verify_file "$BASE_DIR/trytond.conf"
    $PYTHON $TRYTOND/bin/trytond-admin -v -c "$BASE_DIR/trytond.conf" -d $DATABASE -p
}

update_module(){
    if [ "$ALL" == 1 ]; then
        count=0
        while [ "x${MODULES[count]}" != "x" ]
        do
            read NAME REV < <(get_name_rev "${MODULES[count]}")
            MDS=$MDS" "$NAME
            count=$(( $count + 1 ))
        done
    else
        MDS=$MODULE
    fi

    verify_file "$BASE_DIR/trytond.conf"
    link_modules
    if [ "$LOG" == 1 ]; then
        $PYTHON $TRYTOND/bin/trytond-admin -v -c "$BASE_DIR/trytond.conf" -d $DATABASE -u $MDS -vvv --logconf=$BASE_DIR/log.conf
    else
        $PYTHON $TRYTOND/bin/trytond-admin -v -c "$BASE_DIR/trytond.conf" -d $DATABASE -u $MDS
    fi
}

link_sao() {
    unlink "$BASE_DIR/sao"
    ln -s "$REPOSITORY_PATH/gui/sao-$TRYTOND_VERSION.$SAO_REVISION" "$BASE_DIR/sao"
}

download_proteus() {
    download_tar "proteus-$TRYTOND_VERSION.$PROTEUS_REVISION" "$REPOSITORY_PATH/gui" "tar.gz"
}

import_countries() {
    export PYTHONPATH="$TRYTOND:$REPOSITORY_PATH/gui/proteus-$TRYTOND_VERSION.$PROTEUS_REVISION"
    SCRIPT="$REPOSITORY_PATH/modules/trytond_country-$TRYTOND_VERSION.$COUNTRY_REVISION/scripts/import_countries.py"
    $PYTHON $SCRIPT -d $DATABASE -c "$BASE_DIR/trytond.conf"
}

import_currencies() {
    export PYTHONPATH="$TRYTOND:$REPOSITORY_PATH/gui/proteus-$TRYTOND_VERSION.$PROTEUS_REVISION"
    SCRIPT="$REPOSITORY_PATH/modules/trytond_currency-$TRYTOND_VERSION.$CURRENCY_REVISION/scripts/import_currencies.py"
    $PYTHON $SCRIPT -d $DATABASE -c "$BASE_DIR/trytond.conf"
}

download_sao() {
    download_tar "tryton-sao-$TRYTOND_VERSION.$SAO_REVISION" "$REPOSITORY_PATH/gui" "tgz"
    mv "$REPOSITORY_PATH/gui/package" "$REPOSITORY_PATH/gui/sao-$TRYTOND_VERSION.$SAO_REVISION"
    link_sao
}

install_sao() {
    cd "$REPOSITORY_PATH/gui/sao-$TRYTOND_VERSION.$SAO_REVISION"
    echo "Updating npm..."
    npm update -g npm
    echo "npm installing..."
    npm install
    echo "bower installing..."
    bower install
    echo "grunt..."
    grunt
}

download() {
    download_tar "trytond-$TRYTOND_VERSION.$TRYTOND_REVISION" "$REPOSITORY_PATH" "tar.gz"
    count=0
    while [ "x${MODULES[count]}" != "x" ]
    do
        read NAME REV < <(get_name_rev "${MODULES[count]}")
        if [[ $REV == ?(-)+([0-9]) ]]; then
            DIR_NAME="trytond_$NAME-$TRYTOND_VERSION.$REV"
            download_tar $DIR_NAME "$REPOSITORY_PATH/modules" "tar.gz"
        fi
        count=$(( $count + 1 ))
    done
}


lnk() {
    link_modules
}

ulink() {
    echo "Unlinking modules..."
    for entry in "$TRYTOND/trytond/modules"/*
    do
      if [ -d "$entry" ]; then
        echo " $entry"
        unlink $entry
      fi
    done
}

case "$ACTION" in
        run)
            run
            ;;

        run_cron)
            run_cron
            ;;

        init)
            init
            ;;

        test)
            test
            ;;

        download)
            download
            ;;

        download_sao)
            download_sao
            ;;

        install_sao)
            install_sao
            ;;

        link_sao)
            link_sao
            ;;

        download_proteus)
            download_proteus
            ;;

        import_countries)
            import_countries
            ;;

        import_currencies)
            import_currencies
            ;;

        update_module)
            update_module
            ;;

        set_password)
            set_password
            ;;

        lnk)
            lnk
            ;;

        ulink)
            ulink
            ;;

        help)
            show_help
            ;;

        *)
            echo "ERROR: Invalid action $ACTION"
            show_help

esac
