#!/bin/bash

# A Munro: 15 Apr 2016: Nagios nrpe check: checks mounts in a autofs indirect map for readability.

ok=0
warn=1
err=2
unk=3
dtout=30

[[ $1 =~ ^- ]] && {
  echo "Usage: $(basename $0) <full-path-map> <timeout>"
  echo "eg $(basename $0) /etc/auto.remote 30"
  echo "default timeout $dtout seconds."
  echo ""
  exit $ok
}

mp=$1
tout=$2
[ -z "$tout" ] && tout=$dtout
mst=/etc/auto.master

[ -z "$mp" ] && {
  echo "Must supply map file as arg 1."
  exit $unk
}

[ ! -f "$mp" ] && {
  echo "Map $mp not found."
  exit $unk
}

mnt=$(awk -v f="$mp" '$2 == f {print $1}' $mst)

[ -z "$mnt" ] && {
  echo "Map $mp not found $mst."
  exit $unk
}

stat=0
ml=( )
IFS=$'\n'
for l in $(awk '!/^([[:blank:]]+|)#/ {print $1}' $mp)
do
  timeout $tout ls -l $mnt/$l/ > /dev/null 2>&1 || {
    unset IFS
    stat=2
    ml=( ${ml[@]} $mnt/$l )
    IFS=$'\n'
  }
done
unset IFS

if [ $stat -eq 0 ]
then
  echo "OK - All NFS mount/s in $mp readable.|"
  cat $mp
  exit $ok
else
  echo "ERROR - NFS mount/s in $mp not readable:$(echo ${ml[@]}|sed 's/ /,/g')|"
  cat $mp
  exit $err
fi
