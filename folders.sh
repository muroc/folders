#!/bin/bash

#
# MIT License
#
# Copyright (c) 2017 Maciej Chałapuk
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software
# is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
#

PRG=$0

usage() {
  echo "Usage: $PRG <command> [arguments...]" >&2
  echo "">&2
  echo "  Commands:" >&2
  echo "    list - lists added folders" >&2
  echo "    add [folders...] - adds specified folders to the list" >&2
  echo "    del [folders...] - deletes specified folders from the list" >&2
  echo "    run <command-line> - runs specified command on all added folders" >&2
  echo "    usage - shows this message" >&2
  echo "" >&2
}

CMD=$1

# Arguments need to be properly escaped and quoted
# as they will be passed into another shell.
ARGS=""
for ARG in "${@:2}"
do
  ARG="${ARG//\\/\\\\}"
  if grep -q ' ' <<< "$ARG"
  then
    ARGS="$ARGS \"${ARG//\"/\\\"}\""
  else
    ARGS="$ARGS $ARG"
  fi
done

# Group name is derived from program name
# (symlinking the script creates another folder group)
GROUP_NAME=${PRG##*/}

FOLDERS_DB=~/.$GROUP_NAME
test -f $FOLDERS_DB || touch $FOLDERS_DB

# When running in terminal we would like to have colored messages.
if tty -s
then
  cyan() {
    echo -e "\e[36m$@\e[0m"
  }
  green() {
    echo -e "\e[32m$@\e[0m"
  }
  red() {
    echo -e "\e[31m$@\e[0m"
  }
  yellow() {
    echo -e "\e[33m$@\e[0m"
  }
  magenta() {
    echo -e "\e[35m$@\e[0m"
  }
else
  cyan() {
    echo $@
  }
  green() {
    echo $@
  }
  red() {
    echo $@
  }
  yellow() {
    echo $@
  }
  magenta() {
    echo $@
  }
fi

# <COMMANDS>

list() {
  cat $FOLDERS_DB | while read LINE; do cyan $LINE; done
}

add() {
  ls -1d $@ | while read FOLDER
  do
    ADDED=`readlink -f $FOLDER`

    if egrep -q "^$ADDED$" $FOLDERS_DB
    then
      red "already added: $ADDED" >&2
      continue
    fi

    echo `yellow "$GROUP_NAME"`: `green "+"``cyan "$ADDED"`
    echo "$ADDED" >> $FOLDERS_DB
  done
}

del() {
  ls -1d $@ | while read ENTRY
  do
    DELETED=`readlink -f "$ENTRY"`

    if ! egrep -q "^$DELETED$" $FOLDERS_DB
    then
      red "not found: $DELETED" >&2
      continue
    fi

    mv $FOLDERS_DB $FOLDERS_DB.old

    cat $FOLDERS_DB.old | while read FOLDER
    do
      ABSOLUTE_PATH=`readlink -f "$FOLDER"`
      if [[ "$ABSOLUTE_PATH" == "$DELETED" ]]
      then
        echo `yellow "$GROUP_NAME"`: `red "-"``cyan "$DELETED"`
      else
        echo "$ABSOLUTE_PATH" >> $FOLDERS_DB
      fi
    done
  done
}

# tty must not be run inside a function
# (functions have their own input and output descriptors).
TTY=`tty`

run() {
  cat $FOLDERS_DB | while read FOLDER
  do
    echo `yellow $USER@$(cat /etc/hostname)`:`cyan $FOLDER`$ $*

    bash -c "cd $FOLDER; $*" 0<$TTY || true

    echo `magenta EOF`
  done
}

# </COMMANDS>

case "$CMD" in
  "list") ;& "all") list;;
  "add") add $ARGS;;
  "del") ;& "delete") ;& "remove") ;& "rm") del $ARGS;;
  "run") run $ARGS;;
  "help") ;&  "?") ;& "usage") usage;;
  "")
    echo `red "command is required"` >&2
    echo "" >&2
    usage
    ;;
  *)
    echo `red "unknown command: $CMD"` >&2
    echo "" >&2
    usage
    ;;
esac

