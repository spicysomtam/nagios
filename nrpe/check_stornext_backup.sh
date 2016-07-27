#!/bin/bash

# A Munro: 12 Jul 2016
# Check snx backup. Last line tells what happened. Should have successful in it.
# Or backup could be skipped because there are no managed filesystems.

. /root/.bash_profile
. /usr/cvfs/.profile

[ "$(snhamgr status|awk -F'=' '/^LocalStatus/ {print $2}')" != "primary" ] && {
  echo "OK - Host is HA standby."
  exit 0
}

listLog() {
  IFS=$'\n'
  for l in ${ln[@]}
  do
    echo $l
  done
  unset IFS
}

sev=1

IFS=$'\n'
ln=( $(snbackup -s|tail -12) )
unset IFS

txt="WARNING $(echo ${ln[@]: -1}|sed -r -e 's/ +/ /g' -e 's/^ +//' -e 's/== //')"

# Older versions of bash can't do -1 directly; hence:
# The skipped backup is if there are no managed filesystems
[[ ${ln[@]: -1} =~ (ackup\ successfully\ completed|kipping\ backup\ since\ there\ are\ no\ managed\ file) ]] && {
  sev=0
  txt="OK $(echo ${ln[@]: -1}|sed -r -e 's/ +/ /g' -e 's/^ +//' -e 's/== //')"
}

# Still not good; maybe its still running
# This is all about indentation in the messages; if the backup is still running then there will
# be 3 spaces or a hyphen in the messages.
[ $sev -eq 1 ] && [[ "${ln[@]: -1}" =~ \ (-|\ {3,}|Backup Start) ]] && {
  sev=0
  txt="OK $(echo "${ln[@]: -1}"|awk -F'   ' '{print $1}') Backup running."
}

echo $txt
listLog

exit $sev
