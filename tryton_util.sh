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

show_help(){
    echo $"Usage: $0 { help | init | run | test | download }"
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
        echo " Downloading $1"
        wget "https://downloads.tryton.org/$TRYTOND_VERSION/$1.tar.gz"
        mv ./$1.tar.gz $2
        echo " Uncompressing..."
        tar -xzvf $2/$1.tar.gz -C $2
        echo " deleting tar.gz..."
        rm -f $2/$1.tar.gz
    fi
}

verify_file $BASE_DIR/config.sh
source $BASE_DIR/config.sh

ACTION=$1
MODULE=$2

TRYTOND="$BASE_DIR/tryton/trytond-$TRYTOND_VERSION.$TRYTOND_REVISION"
download_tar "trytond-$TRYTOND_VERSION.$TRYTOND_REVISION" "$BASE_DIR/tryton"
verify_dir $TRYTOND

MODULE_DIR=$BASE_DIR/$MODULE
source $MODULE_DIR/config.sh

echo "Running tool for module $MODULE"

# Always clean modules
for entry in "$TRYTOND/trytond/modules"/*
do
  if [ -d "$entry" ]; then
    echo "Unlinking $entry"
    unlink $entry
  fi
done

get_name_rev(){
    INDEX=`expr index "$1" " "`
    NAME_INDEX=$(($INDEX - 1))
    REV_INDEX=$(($INDEX + 1))
    NM=`expr substr "$1" 1 $NAME_INDEX`
    RV=`expr substr "$1" $REV_INDEX $(($REV_INDEX + 1))`
    echo "$NM $RV"
}

link_modules() {
    # Symbolic link for $MODULE
    verify_dir $MODULE_PATH
    ln -s $MODULE_PATH $TRYTOND/trytond/modules/$MODULE

    count=0
    while [ "x${MODULES[count]}" != "x" ]
    do
        read NAME REV < <(get_name_rev "${MODULES[count]}")
        DIRX="$BASE_DIR/modules/trytond_$NAME-$TRYTOND_VERSION.$REV"
        verify_dir $DIRX
        echo "Linking $DIRX"
        ln -s $DIRX "$TRYTOND/trytond/modules/$NAME"

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
    $PYTHON $TRYTOND/bin/trytond-admin -v -c $BASE_DIR/trytond.conf -d $MODULE --all
}

download() {
    source $BASE_DIR/tryton/modules/config.sh
    count=0
    while [ "x${CURRENT_MODULES[count]}" != "x" ]
    do
        read NAME REV < <(get_name_rev "${CURRENT_MODULES[count]}")
        DIR_NAME="trytond_$NAME-$TRYTOND_VERSION.$REV"
        download_tar $DIR_NAME "$BASE_DIR/tryton/modules"
        count=$(( $count + 1 ))
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

        help)
            show_help
            ;;

        *)
            echo "ERROR: Invalid action $ACTION"
            show_help

esac
