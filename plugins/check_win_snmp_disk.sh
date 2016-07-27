#!/bin/bash
# A Munro: 11 Mar 2016.
# Inspired by the perl version of the same name, but it didn't work the way I wanted it.
# For example, we can specify the C: drive and it will pick the right drive out of snmp.
# Also identifies floppy or cdrom drives where the size is 0 bytes.
# Original version did not have performance data in the correct format.
# Rewrite in bash as bash can pretty much do everything the perl version can do

Usage() {
  echo $(basename $0):
  echo -e "\t-h - help."
  echo -e "\t-H - Hostname."
  echo -e "\t-C - Snmp community. default: public."
  echo -e "\t-d - Drive; default C."
  echo -e "\t-w - Warning quota % threshold. default 85."
  echo -e "\t-c - Critical quota % threshold. default 95."
  exit 0
}

# Human readable; convert bytes to whatever is the highest
hr() {

#  Tb rounds up too much because of bash's integer handling; lets stick with Gb
#  ans=$(($1/1024/1024/1024/1024))
#  [ $ans -gt 0 ] && {
#     [ -z "$2" ] && q="Tb"
#     echo "${ans}$q"
#     return
#  }

  ans=$(($1/1024/1024/1024))
  [ $ans -gt 0 ] && {
     [ -z "$2" ] && q="Gb"
     echo "${ans}$q"
     return
  }

  ans=$(($1/1024/1024))
  [ $ans -gt 0 ] && {
     [ -z "$2" ] && q="Mb"
     echo "${ans}$q"
     return
  }

  ans=$(($1/1024))
  [ $ans -gt 0 ] && {
     [ -z "$2" ] && q="Kb"
     echo "${ans}$q"
     return
  }
}

###############################################################
# Main

while getopts "hC:H:w:c:d:" opt; do
  case $opt in
    h)  Usage
        ;;
    H)  host=$OPTARG
        ;;
    C)  comm=$OPTARG
        ;;
    w)  warn=$OPTARG
        ;;
    c)  crit=$OPTARG
        ;;
    d)  drive=${OPTARG^^}
        ;;
    \?) echo "Invalid option: - $OPTARG" >&2
        exit 2
        ;;
  esac
done

[ -z "$host" ] && {
  echo "CRITICAL - host not specified."
  exit 2
}

[ -z "$comm" ] && comm=public
[ -z "$warn" ] && warn=85
[ -z "$crit" ] && crit=95
[ -z "$drive" ] && drive="C"
drive=${drive^^}:

oid=".iso.org.dod.internet.mgmt.mib-2.host.hrStorage.hrStorageTable"

snmpwalk -v 1 $host -c $comm $oid > /dev/null 2>&1 || {
  echo "CRITICAL - unable to communicate via snmp."
  exit 2
}

# Find the index
IFS=$'\n' 
for l in $(snmpwalk -v 1 $host -c $comm $oid|grep hrStorageDescr)
do 
 [[ $l =~ \ $drive\\ ]] && idx=$(echo $l|cut -d'.' -f2|cut -d' ' -f1)
done
unset IFS

[ -z "$idx" ] && {
  echo "CRITICAL - drive $drive not found."
  exit 2
}

#echo $idx # debug

units=$(snmpget -v 1 $host -c $comm $oid.hrStorageEntry.hrStorageAllocationUnits.$idx -t 5| awk '{ print $4,$5 }')

[[ $units =~ Bytes$ ]] || {
  echo "CRITICAL - snmp does not report unit size in bytes. Please investigate plugin."
  exit 2
}

a=( $units )
units=${a[0]}

size=$(snmpget -v 1 $host -c $comm $oid.hrStorageEntry.hrStorageSize.$idx -t 5| awk '{ print $4 }')

# dvd drives and floppies report size 0 when no media mounted
if [ $size -ne 0 ] 
then
  used=$(snmpget -v 1 $host -c $comm $oid.hrStorageEntry.hrStorageUsed.$idx -t 5| awk '{ print $4 }')
  used=$(($used*$units))
  size=$(($size*$units))
  pct=$(($used*100/$size))
  wsize=$(($size*$warn/100))
  csize=$(($size*$crit/100))
  ln=" - $drive drive $pct% used ($(hr $used)/$(hr $size)).|'$drive'=$(hr $used);$(hr $wsize no);$(hr $csize no);0;$(hr $size no)"
else
  pct=0
  ln=" - $drive drive size 0 bytes. Floppy or cdrom drive?|'$drive'=0KB;;;;"
fi

[ $pct -gt $crit ] && {
  echo "CRITICAL$ln"
  exit 2
}

[ $pct -gt $warn ] && {
  echo "WARNING$ln"
  exit 1
}

echo "OK$ln"
exit 0
