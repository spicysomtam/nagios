#!/bin/bash

# A Munro: 4 Sep 2015
# scan a state file for hosts and services enabled/disabled.
# Used this as a migration tool from one nagios to another.
# That is only migrate services/hosts that are enabled (active).
# Investigate those that are disabled.

usage() {
  echo "$(basename $0): -f <state-file> [ -s enabled|disabled ] [ -H <host> ] [-h]"
  echo "                 Scan a nagios state.dat file for services|hosts enabled|disabled."
  echo "                 For disabled shows all downtime and comments."
  echo "                 -H filters for a host; -s does not need to be specified."
  echo ""
  exit 0
}

while getopts ":f:s:H:h" opt; do
  case $opt in
    f) in=$OPTARG
      ;;
    s) state=$OPTARG
      ;;
    H) host=$OPTARG
      ;;
    h) usage
      ;;
   \?) usage
      ;;
  esac
done

[ -z "$in" ] && { \
  echo Specify status file.
  exit 1
}

[ -f "$in" ] || { \
  echo $in not found.
  exit 1
}

[ -z "$host" ] && { \
   [[ $state =~ ^(enabled|disabled)$ ]] || { \
     echo State needs to be enabled or disabled.
     exit 1
   }
}

fl=1
[ "$state" == "disabled" ] && fl=0

IFS=$'\n'
for l in $(cat $in)
do
  [[ $l =~ ^[[:blank:]] ]] || t=${l% *}
  [[ $l =~ host_name= ]] && h=${l#*=}
  [[ $l =~ notifications_enabled= ]] && n=${l#*=}
  [[ $l =~ service_description= ]] && sd=${l#*=}
  [[ $l =~ check_command= ]] && cc=${l#*=}
  [[ $l =~ comment= ]] && com=${l#*=}
  [[ $l =~ comment_data= ]] && com=${l#*=}
  [[ $l =~ author= ]] && auth=${l#*=}
  [[ $l =~ entry_time= ]] && et=$(date --date="@${l#*=}" "+%d-%b-%Y %H:%M:%S")
  [[ $l =~ start_time= ]] && st=$(date --date="@${l#*=}" "+%d-%b-%Y %H:%M:%S")
  [[ $l =~ end_time= ]] && et=$(date --date="@${l#*=}" "+%d-%b-%Y %H:%M:%S")

  [[ $l =~ ^[[:blank:]]\} ]] && { \
    [ ! -z "$host" ] && [ "$host" != "$h" ] && continue

    if [ -z "$host" ]
    then
      [ $t == "hoststatus" ] && [ $n -eq $fl ] && echo "$t host=\"$h\" notifications=\"$state\""
      [ $t == "servicestatus" ] && [ $n -eq $fl ] && \
        echo "$t host=\"$h\" service=\"$sd\" notifications=\"$state\" check_command=\"$cc\""
    else
      state=enabled
      [ $n -eq 0 ] && state=disabled
      [ $t == "hoststatus" ] && [ $host == $h ] && echo "$t host=\"$h\" notifications=\"$state\""
      [ $t == "servicestatus" ] && [ $host == $h ] && \
        echo "$t host=\"$h\" service=\"$sd\" notifications=\"$state\" check_command=\"$cc\""
    fi

    [ $t == "hostdowntime" ] && [ $fl -eq 0 ] && \
      echo "$t host=\"$h\" author=\"$auth\" start=\"$st\" end=\"$et\" comment=\"$com\""
    [ $t == "serviedowntime" ] && [ $fl -eq 0 ] && \
      echo "$t host=\"$h\" service=\"$sd\" author=\"$auth\" start=\"$st\" end=\"$et\" comment=\"$com\""
    [ $t == "hostcomment" ] && [ $fl -eq 0 ] && \
      echo "$t host=\"$h\" author=\"$auth\" entered=\"$et\" comment=\"$com\""
    [ $t == "servicecomment" ] && [ $fl -eq 0 ] && \
      echo "$t host=\"$h\" service=\"$sd\" author=\"$auth\" entered=\"$et\" comment=\"$com\""
  }
done
