#!/bin/bash

# A Munro 22 Jan 2016: ssh to an isilon (gui/cluster address) and search for alerts not yet handled
# that are not informational or warning events.
#
# Update history:
# A Munro 28 Jan 2016: We cannot excluded info and warning as these may be important; thus we need to filter out unwanted messages. Please add to the filter list as we gte them over time.
# A Munro 25 Apr 2016: Exclude 'Software license 'InsightIQ' expired' issues.
# A Munro 18 May 2016: Somehow ssh keys got removed from isilons and script does not check ssh password less access. Thus check ssh access firstly. This was result of onefs upgrade.
#                      Upgrade to OneFS V8.0.0.0: commands have changed. 'isi events' no longer lists events; have to use 'isi event list' now.
#                      Use ssh rather than check_by_ssh; check_by_ssh does some wierd terminal hacking.

NAGLIBEXEC=/usr/lib64/nagios/plugins
#SSH="$NAGLIBEXEC/check_by_ssh -H $1 -q -t 1 -l root -C"
SSH="ssh -oConnectTimeout=3 -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -oBatchMode=yes -oLogLevel=quiet -l root $1"

# Test ssh; since sometimes ssh keys get removed...
$SSH 'isi event list' > /dev/null 2>&1 || {
  #reset # seems check_by_ssh screws up the terminal; lets reset it
  echo "CRITICAL unable to access via ssh. Check root ssh keys on isilon, etc."
  exit 2
}

# Example events from isi event list
#131092 05/17 17:38 05/17 17:38 SYS_DISK_REMOVED                 1       critical   
#131102 05/17 17:47 --          SYS_DISK_UNHEALTHY               1       critical   

issues=()
#for l in $($SSH "isi events"|awk 'NR > 1 && $4 == "--" {print $1}') # debug
#for l in $($SSH "isi events"|awk 'NR > 1 && $4 == "--" && $5 !~ /^(I|W)$/ {print $1}')
#for l in $($SSH "isi events"|awk 'NR > 1 && $4 == "--" {print $1}') # Pre v8
for l in $($SSH "isi event list "|awk 'NR > 1 && $4 == "--" {print $1}')
do
  issues+=( $l )
done

#echo ${issues[@]} # debug

#echo "CRITICAL ${#issues[@]} isilon alert/s found."

lines=()
for l in ${issues[@]}
do
  node=""
  #o=$($SSH "isi events show $l"|awk '{ if (/Message:/) {m=substr($0,15)}; if (/Node:/) {n=substr($0,15)}; if (/Severity:/) {s=substr($0,15)} } END {if (n == "All") {n="Cluster"} else {n="Node "n}; printf("%s: %s: %s\n", n,s,m)}') # Pre v8
  o=$($SSH "isi event view $l"|awk -F': ' '/^Causes Long:/ {print $2}')
  #echo $o # debug

# Events we don't want; add to this list:
  [[ $o =~  Mount ]] && continue
  [[ $o =~  Software\ license\ \'SmartPools\'\ expired ]] && continue
  [[ $o =~  Software\ license\ \'InsightIQ\'\ expired ]] && continue
  # Otherwise we want it

  # Prev v8 allowed as to easily pick the node out from isi events show. Now we need to pick it out from 'isi event event list'
  # There may be multiple events
  node=$($SSH 'isi event event list'|awk -v ev=$l '$6 == ev {print $5}'|sort -u)

  #echo $node # debug
  [ -z "$node" ] && node=0
  [ $node -ne 0 ] && o="Node$node: $o"
  [ $node -eq 0 ] && o="Cluster: $o"
  o="$l: $o"

  # so add to array
  lines+=( "$o" )
done

[ ${#lines[@]} -eq 0 ] && {
  echo "OK No isilon alerts found."
  exit 0
}

echo "CRITICAL ${#lines[@]} isilon alert/s found."

IFS=$'\n'
for l in ${lines[@]}
do
  echo $l
done

exit 2
