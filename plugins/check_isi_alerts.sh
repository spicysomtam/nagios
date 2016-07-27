#!/bin/bash

# A Munro 22 Jan 2016: ssh to an isilon (gui/cluster address) and search for alerts not yet handled
# that are not informational or warning events.
#
# Update history:
# A Munro 28 Jan 2016: We cannot excluded info and warning as these may be important; thus we need to filter out unwanted messages. Please add to the filter list as we gte them over time.
# A Munro 25 Apr 2016: Exclude 'Software license 'InsightIQ' expired' issues.

NAGLIBEXEC=/usr/lib64/nagios/plugins

issues=()
#for l in $($NAGLIBEXEC/check_by_ssh -H $1 -l root -C "isi events"|awk 'NR > 1 && $4 == "--" {print $1}') # debug
#for l in $($NAGLIBEXEC/check_by_ssh -H $1 -l root -C "isi events"|awk 'NR > 1 && $4 == "--" && $5 !~ /^(I|W)$/ {print $1}')
for l in $($NAGLIBEXEC/check_by_ssh -H $1 -l root -C "isi events"|awk 'NR > 1 && $4 == "--" {print $1}')
do
  issues+=( $l )
done

#echo ${#issues[@]} # debug

#echo "CRITICAL ${#issues[@]} isilon alert/s found."

lines=()
for l in ${issues[@]}
do
  o=$($NAGLIBEXEC/check_by_ssh -H $1 -l root -C "isi events show $l"|awk '{ if (/Message:/) {m=substr($0,15)}; if (/Node:/) {n=substr($0,15)}; if (/Severity:/) {s=substr($0,15)} } END {if (n == "All") {n="Cluster"} else {n="Node "n}; printf("%s: %s: %s\n", n,s,m)}')

# Events we don't want; add to this list:
  [[ $o =~  Mount ]] && continue
  [[ $o =~  Software\ license\ \'SmartPools\'\ expired ]] && continue
  [[ $o =~  Software\ license\ \'InsightIQ\'\ expired ]] && continue

# Otherwise we want it; so add to array
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
