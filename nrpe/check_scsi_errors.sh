#!/bin/bash

# A Munro 04 Apr 2016: They want to check for SCSI errors in messages, so here goes.
# Pass the number of hours before to check. Default is 3. So if its 15:24, it will check 13:00 onwards (only checks the hr portion)
# If hr is 0 then it only checks from the beginning of the day.
# rh4 bash 3 does not support +=; so some tweaks to make it backward compatible.

hr=$1

[ -z "$hr" ] && hr=3

if [ $(lsb_release -i|awk '{print $3}') == "Ubuntu" ]
then
  l=/var/log/syslog
else
  l=/var/log/messages
fi

# Filter on todays date
m=$(date "+%b")
d=$(date "+%d")
h=$(date "+%k") # 24 Hour

c=$h
while [ 1 -eq 1 ]
do
  [[ $c =~ ^[0-9]$ ]] && c="0$c"
  IFS=$'\n'
  #f=( ${f[@]} $(awk -v m=$m -v d=${d#0} -v p="^$c" '$1 == m && $2 == d && $3 ~ p ' $l|sort -u) ) # debug
  f=( ${f[@]} $(awk -v m=$m -v d=${d#0} -v p="^$c" '$1 == m && $2 == d && $3 ~ p && /( scsi:|SCSI device|SCSI error)/ && !/drive cache: (write|none)/ && !/-byte hdwr sectors/' $l|sort -u) )
  [ $c -eq 0 ] && break
  [[ $c =~ ^0 ]] && c=$(echo $c|cut -c2-)
  c=$(($c-1))
  [ $c -eq $(($h -$hr)) ] && break
done

[ ${#f[@]} -eq 0 ] && {
  echo "OK - No SCSI errors found in $l.|"
  unset IFS
  exit 0
}

echo "WARNING - SCSI errors found in $l.|"
for ln in ${f[@]}
do
  echo $ln
done
unset IFS
exit 1
