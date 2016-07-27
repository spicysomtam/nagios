#!/bin/bash

# A Munro: 13 Jun 2016
# A Stornext nrpe plugin to check number of tapes that need defragging.
# Since some of our snx vips don't work, these scripts need to be able to work
# on both ha nodes.

. /root/.bash_profile
. /usr/cvfs/.profile

[ "$(snhamgr status|awk -F'=' '/^LocalStatus/ {print $2}')" != "primary" ] && {
  echo "OK - Host is HA standby."
  exit 0
}

usage() {
  echo "$(basename $0): -w <warn> -c <crit> [-h]"
  echo "  Check number of defrag tapes."
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

[ -z "$w" ] && {
  echo "WARNING - warning number of tapes not specified!"
  exit 1
}

[ -z "$c" ] && {
  echo "WARNING - critical number of tapes not specified!"
  exit 1
}

[ $w -gt $c ] && {
  echo "WARNING - warning $w tapes greater than critical $c tapes!"
  exit 1
}

t=/var/tmp/defrag_$$.log

fsdefrag > $t 2>&1

grep -q "No available full media were found to be at" $t && {
  echo "OK - No tapes need defragging."
  [ -f $t ] && cat $t && rm -f $t
  exit 0
}

n=$(awk '$NF == "Y" || $NF == "N" {c+=1} END {print c}' $t)
#echo $n # debug

[ $n -gt $c ] && {
  echo "CRITICAL - $n tapes need defragging (>$c)!"
  [ -f $t ] && cat $t && rm -f $t
  exit 2
}

[ $n -gt $w ] && {
  echo "WARNING - $n tapes need defragging (>$w)!"
  [ -f $t ] && cat $t && rm -f $t
  exit 1
}

echo "OK - $n tapes need defragging (warn>$w;crit>$c)."
[ -f $t ] && cat $t && rm -f $t
exit 0

