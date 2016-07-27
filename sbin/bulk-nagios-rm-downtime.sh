#!/bin/bash

# A Munro: 19 Apr 2016: schedule downtimes based on a passed filename or hostname.
#
# Modification history:
# A Munro: 20 Apr 2016: 
# Original method of using pynag in a for loop for each host really slow
# as each iteration of pynag loads all downtimes into a dict. Thus this method
# only runs pynag once to get all the downtimes and then uses the nagios command
# interface to remove the downtimes. Original method:
# echo y|pynag downtime --remove where host_name=$i                      
# 646 hosts at 1.5 mins foreach pynag iteration would mean over 16 hours to remove the downtimes.
# This new version took just under 9 minutes.

# Args:
# $1: hostname or .lis filename.

if [[ $1 =~ \.lis$ ]]
then
  [ ! -f $1 ] && {
    echo "File $1 not found."
    exit 1
  }
  h=( $(cat $1) )
else
  h=( $1 )
fi

commandfile=/var/spool/nagios/cmd/nagios.cmd

IFS=$'\n'
dwn=( $(pynag downtime --list) )
#dwn=( $(cat a) ) # debug
unset IFS

for i in ${h[@]}
do
  IFS=$'\n'
  for d in ${dwn[@]}
  do
    [[ $d =~ ^-- ]] && continue
    unset IFS
    f=( $d )
    [ ${f[1]} == $i ] && {
      #echo "$d" # debug
      now=$(date +%s)
      if [ "$(echo "$d"|cut -c43)" == " " ]
      then
        # Host downtime
        /usr/bin/printf "[%lu] DEL_HOST_DOWNTIME;${f[0]}\n" $now > $commandfile
      else
        # Service downtime
        /usr/bin/printf "[%lu] DEL_SVC_DOWNTIME;${f[0]}\n" $now > $commandfile
      fi
    }
  done
  unset IFS
done
