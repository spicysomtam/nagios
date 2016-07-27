#!/bin/bash

# A Munro 13 Jul 2016: ssh to an isilon (gui/cluster address) and check for lots of close_waits.
# 1st arg: hostname
# 2nd arg: no close_waits to exceed. Default 20
#
# Update history:

NAGLIBEXEC=/usr/lib64/nagios/plugins
#SSH="$NAGLIBEXEC/check_by_ssh -H $1 -q -t 1 -l root -C"
SSH="ssh -oConnectTimeout=3 -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oBatchMode=yes -oLogLevel=quiet -l root $1"

# Test ssh; since sometimes ssh keys get removed...
$SSH 'isi event list' > /dev/null 2>&1 || {
  #reset # seems check_by_ssh screws up the terminal; lets reset it
  echo "CRITICAL unable to access via ssh. Check root ssh keys on isilon, etc."
  exit 2
}

cw=$2
[ -z "$cw" ] && cw=20

l=/var/tmp/isi_cw_$1_$$
l=/var/tmp/isi_cw_10.96.198.110_13354
cmd="isi_for_array -s \"netstat -an|grep -i close_wait|wc -l\""
$SSH "$cmd" > $l 2>&1 || {
  echo "CRITICAL Error or timeout issuing command $cmd."
  [ -s $l ] && cat $l
  [ -e $l ] && rm -f $l
  exit 2
}

hosts=""
IFS=$'\n'
for ln in $(cat $l)
do
  #echo $ln # debug
  unset IFS
  f=( $(echo $ln|sed 's/://') )
  f[0]=$(echo ${f[0]}|awk -F'-' '{print $NF}')
  [ ${f[1]} -gt $cw ] && hosts+="node${f[0]}=${f[1]} "
done
unset IFS

if [ ! -z "$hosts" ]
then
  dwn=$(sed  's/^.*down: //' $l|awk -F', ' '{print $1}')
  echo "CRITICAL Isilon nodes > $cw close_waits: $hosts"
  cat $l
  rm -f $l
  exit 2
else
  echo "OK No isilon nodes > $cw close_waits."
  cat $l
  [ -e $l ] && rm -f $l
  exit 0
fi
