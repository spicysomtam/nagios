#!/bin/bash

# A Munro: 06 Jun 2016
# nrpe plugin to check storage manager capacity.
# Since some of our snx vips don't work, these scripts need to be able to work
# on both ha nodes.

. /root/.bash_profile
. /usr/cvfs/.profile

[ "$(snhamgr status|awk -F'=' '/^LocalStatus/ {print $2}')" != "primary" ] && {
  echo "OK - Host is HA standby."
  exit 0
}

usage() {
  echo "$(basename $0): -w <warn%> -c <crit%> [-h]"
  echo "  Check storage manager license capacity."
  echo ""
  exit 0
}

while getopts ":w:c:h" opt; do
  case $opt in
    w) w=$OPTARG
      ;;
    c) c=$OPTARG
      ;;
    h) usage
      ;;
   \?) usage
      ;;
  esac
done

[ $w -gt $c ] && {
  echo "WARNING - warning % greater than critical %!"
  exit 1
}

t=$(sntsm -l -v manager|awk '/Licensed capacity:/ {print $NF}'|sed 's/T//') # In Tb
u=$(sntsm -l -v manager|awk '/Current used capacity:/ {print $NF}'|sed 's/M//') # In Mb
u=$(($u/1024/1024)) # convert Mb to Tb
p=$(($u*100/$t)) # percent

#echo $p $t $u # debug

[ $p -gt $c ] && {
  echo "CRITICAL - Manager license usage $p% (>$c%;${u}Tb/${t}Tb)!"
  sntsm -l -v manager
  exit 2
}

[ $p -gt $w ] && {
  echo "WARNING - Manager license usage $p% (>$w%;${u}Tb/${t}Tb)!"
  sntsm -l -v manager
  exit 1
}

echo "OK - Manager license usage $p% (${u}Tb/${t}Tb)."
sntsm -l -v manager
exit 0

