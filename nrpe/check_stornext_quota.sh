#!/bin/bash

# A Munro: 13 Jun 2016: Quota check via nrpe.
# To keep this generic, pass a pattern match of what to check.
# So it builds a list of all quotas for all cvfs filesystems, orders this,
# and then the list file can be searched for the pattern match.
# This version is designed to run on the stornext appliance rather than 
# snx-quota-list.sh that generates a listing file that is picked up by
# snx-quota-chk.sh, which runs on one of the stornext clients.
#
# Note if u are going to send a $ as your regex from Nagios, add it in as $$!!!

. /root/.bash_profile
. /usr/cvfs/.profile

[ "$(snhamgr status|awk -F'=' '/^LocalStatus/ {print $2}')" != "primary" ] && {
  echo "OK - Host is HA standby."
  exit 0
}

# Human readable; convert bytes to whatever is the highest
hr() {

#  Tb rounds up too much because of bash's integer handling; lets stick with Gb
#  ans=$(($1/1024/1024/1024/1024))
#  [ $ans -gt 0 ] && {
#     echo "${ans}Tb"
#     return
#  }

  ans=$(($1/1024/1024/1024))
  [ $ans -gt 0 ] && {
     echo "${ans}Gb"
     return
  }

  ans=$(($1/1024/1024))
  [ $ans -gt 0 ] && {
     echo "${ans}Mb"
     return
  }

  ans=$(($1/1024))
  [ $ans -gt 0 ] && {
     echo "${ans}Kb"
     return
  }

}


usage() {
  echo "$(basename $0): -q <pattern> -w <warn%> -c <crit%> [-h]"
  echo "  Check stornext quota."
  echo "  -h - help"
  echo "  -q - Directory pattern match. eg system$ ^/prod-.*/Lev1/etl$ etc"
  echo "  -d - print debug info such as the directories matched."
  echo ""
  exit 0
}

deb=0
while getopts ":w:c:q:hd" opt; do
  case $opt in
    q) q=$OPTARG
      ;;
    w) w=$OPTARG
      ;;
    c) c=$OPTARG
      ;;
    d) deb=1
      ;;
    h) usage
      ;;
   \?) usage
      ;;
  esac
done


# Build a list of cvfs filesystems
fs=( $(df -Pt cvfs|awk '!/(^File|HAM\/shared$|blockpool$)/ {print $NF}') )

lis=/var/tmp/snquota_$$.lis

[ -f $lis ] && rm -f $lis

IFS=$'\n' fss=( $(sort <<<"${fs[*]}") )
for f in ${fss[@]}
do
  #echo $f # debug
  snquota -e -L -P $f 2>/dev/null|awk '$6 == "dir"'|awk -v fs=$f '{print fs,$0}'|sort -k1.1,1.8 -k8 > ${lis}.tmp
  cat ${lis}.tmp >> $lis
done

rm -f ${lis}.tmp

# snquota fields:
# HardLimit SoftLimit GracePer CurSize Status Type Name

critm=()
warnm=()
okm=()
sev=0
IFS=$'\n' 
for l in $(cat $lis)
do
  #echo $l # debug
  unset IFS
  f=( $l )
  d=${f[0]}${f[7]}
  [[ $d =~ $q ]] && {
    [ $deb -eq 1 ] && echo $l

    [ ${f[5]} == "NoLimit" ] && {
      [ $sev -eq 0 ] && sev=1
      warnm+=( "$d has no quote set (NoLimit)." )
      continue
    }

#   check soft and hard quotas are the same
    [ ${f[1]} -ne ${f[2]} ] && {
      [ $sev -eq 0 ] && sev=1
      warnm+=( "$d soft and hard quotas not the same ($(hr ${f[2]}) $(hr ${f[1]}))" )
    }

#   Man page says hard limit is absolute limit not to be exceeded, so we use this to work out the %
    pct=$(( ${f[4]} * 100 / ${f[1]}))
    [ $deb -eq 1 ] && echo "$pct%" 

    [ $pct -gt $c ] && {
      [ $sev -le 1 ] && sev=2
      critm+=( "$d quota ${pct}% ($(hr ${f[4]})/$(hr ${f[1]});>$c%)" )
      continue
    }

    [ $pct -gt $w ] && {
      [ $sev -eq 0 ] && sev=1
      warnm+=( "$d quota ${pct}% ($(hr ${f[4]})/$(hr ${f[1]});>$w%)" )
      continue
    }
    okm+=( "$d quota ${pct}% ($(hr ${f[4]})/$(hr ${f[1]}))" )
  }
done
unset IFS

rm -f $lis

[ $sev -eq 0 ] && {
  echo "OK - Quota check/s passed for $q."
  IFS=$'\n'
  for l in ${okm[@]}
  do
    echo $l
  done
  unset IFS
  exit $sev
}

tot=$((${#critm[@]}+${#warnm[@]}))
case $sev in
  1) echo -n "WARNING - "
    [ $tot -gt 1 ] && echo "$tot quotas for $q have issues or > $w% used."
  ;;
  2) echo -n "CRITICAL - "
    [ $tot -gt 1 ] && echo "$tot quotas for $q have issues or > $w% used."
    IFS=$'\n'
    for l in ${critm[@]}
    do
      echo $l
    done
    unset IFS
  ;;
esac

IFS=$'\n'
for l in ${warnm[@]}
do
  echo $l
done
unset IFS

exit $sev

