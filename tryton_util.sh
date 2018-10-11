#!/bin/bash

# tryton_util.sh v1.0
#
# A simple bash script for tryton tasks.
#
# Copyright (C) 2018 Fredy Ramirez - <http://www.formateli.com>
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


BASE_DIR=$PWD

if [ ! -d "$BASE_DIR/tryton" ]; then
    mkdir "$BASE_DIR/tryton"
fi

if [ ! -d "$BASE_DIR/tryton/gui" ]; then
    mkdir "$BASE_DIR/tryton/gui"
fi

show_help(){
    echo $"Usage: $0 { help | init | run | test | download | download_sao | update_module | set_password | ulink}"
    exit
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
        echo " Downloading $1 ..."
        wget "https://downloads.tryton.org/$TRYTOND_VERSION/$1.$3"
        mv ./$1.$3 $2
        echo " Uncompressing..."
        tar -xzvf $2/$1.$3 -C $2
        echo " deleting $3..."
        rm -f $2/$1.$3
    fi
}

verify_file $BASE_DIR/config.sh

# Get TRYTOND_VERSION, TRYTOND_REVISION, SAO_REVISION,
# PYTHON, DEVELOP_PATH, REPORITORY_PATH, MODULES
source $BASE_DIR/config.sh

ACTION=""
DATABASE=""
MODULE=""
ALL=0

while getopts a:d:m:x option
do
case "${option}" in
        a) ACTION=${OPTARG};;
        d) DATABASE=${OPTARG};;
        m) MODULE=${OPTARG};;
        x) ALL=1;;
    esac
done

TRYTOND="$BASE_DIR/tryton/trytond-$TRYTOND_VERSION.$TRYTOND_REVISION"

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
    echo "Linking modules..."
    count=0
    while [ "x${MODULES[count]}" != "x" ]
    do
        read NAME REV < <(get_name_rev "${MODULES[count]}")
        if [[ $REV == ?(-)+([0-9]) ]]; then
            DIRX="$REPORITORY_PATH/trytond_$NAME-$TRYTOND_VERSION.$REV"
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
    $PYTHON $TRYTOND/bin/trytond -v -c $BASE_DIR/trytond.conf
}

test() {
    export PYTHONPATH=$TRYTOND
    link_modules
    $PYTHON $TRYTOND/trytond/tests/run-tests.py -v -f -m $MODULE
}

init() {
    verify_file "$BASE_DIR/trytond.conf"
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
    $PYTHON $TRYTOND/bin/trytond-admin -v -c "$BASE_DIR/trytond.conf" -d $DATABASE -u $MDS
}

download_sao() {
    if [ ! -d "$BASE_DIR/tryton/gui" ]; then
        mkdir "$BASE_DIR/tryton/gui"
    fi
    download_tar "tryton-sao-$TRYTOND_VERSION.$SAO_REVISION" "$BASE_DIR/tryton" "tgz"
    mv "$BASE_DIR/tryton/package" "$BASE_DIR/tryton/sao-$TRYTOND_VERSION.$SAO_REVISION"
    ln -s "$BASE_DIR/tryton/sao-$TRYTOND_VERSION.$SAO_REVISION" "$BASE_DIR/tryton/gui/sao"
}

install_sao() {
    cd "$BASE_DIR/tryton/sao-$TRYTOND_VERSION.$SAO_REVISION"
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
    download_tar "trytond-$TRYTOND_VERSION.$TRYTOND_REVISION" "$BASE_DIR/tryton" "tar.gz"
    count=0
    while [ "x${MODULES[count]}" != "x" ]
    do
        read NAME REV < <(get_name_rev "${MODULES[count]}")
        if [[ $REV == ?(-)+([0-9]) ]]; then
            DIR_NAME="trytond_$NAME-$TRYTOND_VERSION.$REV"
            download_tar $DIR_NAME "$REPORITORY_PATH" "tar.gz"
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
