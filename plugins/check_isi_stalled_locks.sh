#!/bin/bash

# A Munro 5 Jul 2016: ssh to an isilon (gui/cluster address) and search all nodes for stalled locks.
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

l=/var/tmp/isi_lck_$1_$$
#cmd="isi status" # debug; for testing
cmd="isi_for_array sysctl efs.lin.lock.initiator.oldest_waiter"
$SSH "$cmd" > $l 2>&1 || {
  echo "CRITICAL Error or timeout issuing command $cmd."
  [ -s $l ] && cat $l
  [ -e $l ] && rm -f $l
  exit 2
}

if [ -s $l ]
then
  echo "WARNING Stalled locks found."
  cat $l
  rm -f $l
  exit 1
else
  echo "OK No stalled locks found."
  [ -e $l ] && rm -f $l
  exit 0
fi
