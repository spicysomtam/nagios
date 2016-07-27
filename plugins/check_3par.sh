#!/bin/bash

# 3PAR Nagios check script v0.2
# Last update 2010/05/14 fredl@3par.com
# Last update 2011/03/03 ddu@antemeta.fr
#
# Change history: A Munro 
# Make it compatible with 3par 3.2.1. For example -nohdtot no longer exists as an option.
# Pretty much a rewrite, but thanks to the original authors for the pointers. 
# This version only uses ssh; why would you use anything else?
#
# This script is provided "as is" without warranty of any kind and 3PAR specifically disclaims all implied warranties of merchantability, 
# non-infringement and fitness for a particular purpose. In no event shall 3PAR have any liability arising out of or related to 
# customer's 'use of the script including lost data, lost profits, or any direct or indirect, incidental, special, or 
# consequential damages arising there from.
# In addition, 3PAR reserves the right not to perform fixes or updates to this script
#
#
# Usage : 3par InServ Username Command
#
# Supported checks
#	phydisk : 	Check status of physical disks
#
#	node : 	Check status of controller nodes
#
#	nodepsu : Check node power supplies
#
#	enc: Enclosures or as 3par call them cages
#
#	virtvol : 	Check status of virtual volumes
#
#	logdisk :	Check status of logical disks
#
#	fc_sfp:	Check fc sfp's
#
#       ports : Check status of ports
#
#	cap : Check used disk capacity; this uses the warn and crit thresholds.
#       You can use arg -t (type) to select different disk types (default all disks; which is fine for us as we only have an ssd 3par).
#

Usage() {
  echo $(basename $0):
  echo -e "\t-h - help."
  echo -e "\t-H - hostname."
  echo -e "\t-C - check."
  echo -e "\t-u - ssh username; typically 3paradm."
  echo -e "\t-w - warning % threshold. default 80."
  echo -e "\t-c - critical % threshold. default 90."
  echo -e "\t-t - disk type; eg ssd, nl, fc; optional; -devtype for showpd."
  echo ""
  echo "Checks available ${checks[@]}"
  exit 0
}

errcnt() {
  echo Could not connect to $host.
  [[ ! $tf =~ \/a$ ]] && [ -e $tf ] && rm -f $tf
  exit 3
}

statexit() {
  m=$1
  f=$2
  s=$3

  case $s in
    0) t="OK -"
      ;;
    1) t="WARNING -"
      ;;
    2) t="CRITICAL -"
      ;;
  esac

  echo "$t $m"
  cat $f
  [[ ! $f =~ \/a$ ]] && [ -e $f ] && rm -f $f
  exit $s
}

###############################################################################
# Main()
tmpdir=/var/tmp
checks=(phydisk node nodepsu enc virtvol logdisk fc_sfp ports cap)

while getopts "hH:u:C:c:w:t:" opt; do
  case $opt in
    h)  Usage
        ;;
    H)  host=$OPTARG
        ;;
    u)  user=$OPTARG
        ;;
    w)  warn=$OPTARG
        ;;
    c)  crit=$OPTARG
        ;;
    t)  devtype=$OPTARG
        ;;
    C)  check=$OPTARG
        ;;
    \?) echo "Invalid option: - $OPTARG" >&2
        exit 2
        ;;
  esac
done

[ -z "$host" ] && {
   echo "Hostname not specified!"
   exit 2
}

[ -z "$user" ] && {
   echo "Username not specified!"
   exit 2
}

[ -z "$check" ] && {
   echo "Check not specified!"
   exit 2
}

f=0
for i in ${checks[@]}
do
  [ $i == $check ] && f=1
done

[ $f -eq 0 ] && {
   echo "Invalid check $check!"
   exit 2
}

[ -z "$warn" ] && warn=80
[ -z "$crit" ] && crit=90

PCCRITICALNL=90
PCWARNINGNL=80
SSH="ssh $user@$host"

tf=$tmpdir/3par_$host_$check_$$.out

[ $check == "phydisk" ] && {
  $SSH showpd > $tf || errcnt
  #tf=~/a # debug

  if [ -z "$(awk '$2 != "total" && NF > 2 && !/^Id/ && $5 != "normal"' $tf)" ]
  then
     statexit "all physical disks have normal status.|" $tf 0
  else
     statexit "physical disk/s not normal: $(awk '$2 != "total" && NF > 2 && !/^Id/ && $5 != "normal" {printf("disk%s(%s)=%s ",$1,$2,$5)}' $tf|sed 's/  / /g')|" $tf 2
  fi
}

[ $check == "node" ] && {
  $SSH shownode > $tf || errcnt
  #tf=~/a # debug

  # Status should be ok and it should be in cluster.
  if [ ! -z "$(awk '!/(^Node|Cache$)/ && ($3 != "OK" || $5 != "Yes")' $tf)" ]
  then
    statexit "nodes not OK or InCluster is not Yes: $(awk '!/(^Node|Cache$)/ && ($3 != "OK" || $5 != "Yes") {printf("node%s=%s,%s ",$1,$3,$5)}' $tf)|" $tf 2
  else
    statexit "all nodes ok and in cluster.|" $tf 0
  fi
}

[ $check == "nodepsu" ] && {
  $SSH shownode -ps > $tf || errcnt
  #tf=~/a # debug

  if [ ! -z "$(awk '!/^Node/ && ($5 != "OK" || $6 != "OK" || $7 != "OK")' $tf)" ]
  then
    statexit "node power supplies not ok: $(awk '!/^Node/ && ($5 != "OK" || $6 != "OK" || $7 != "OK") {printf("psu%s=%s,%s,%s ",$2,$7,$5,$6)}' $tf)|" $tf 2
  else
    statexit "all node power supply/s have normal status.|" $tf 0
  fi
}

[ $check == "enc" ] && {
  $SSH showcage -d > $tf || errcnt
  #tf=~/a # debug

  cage=( $(awk '/ [0-9]* cage/ {printf("%s ", $2)}' $tf) )

  stat=0 # assume all is good

  IFS=$'\n'
  for l in $(cat $tf)
  do
     # Get index into array
     #-----------Cage detail info for cage0 ---------
     [[ $l =~ Cage\ detail\ info\ for ]] && ca=$(echo $l|cut -d' ' -f5|sed 's/cage//')

     # Check interface cards
     # State(self,partner)            OK,OK            OK,OK
     [[ $l =~ ^\ State ]] && {
       unset IFS
       a=( $l )

       for i in 1 2
       do
         [ ${a[$i]} != "OK,OK" ] && {
           [[ ${cage[$ca]} =~ = ]] && cage[$ca]+=",card$(($i-1))"
           [[ ! ${cage[$ca]} =~ = ]] && cage[$ca]+="=card$(($i-1))"
           [ $stat -eq 0 ] && stat=1
         }
       done
       IFS=$'\n'
     }

     # Check power supplies
     #ps1      OK      OK      OK        OK        Low        Low
     [[ $l =~ ^ps ]] && [[ ! $l =~ OK\ +OK\ +OK\ +OK\ +Low\ +Low$ ]] && {
       ps=$(echo "$l"|awk '{print $1}')
       [[ ${cage[$ca]} =~ \= ]] && cage[$ca]+=",$ps"
       [[ ! ${cage[$ca]} =~ \= ]] && cage[$ca]+="=$ps"
       [ $stat -eq 0 ] && stat=1
     }
     # check disks
     #  6:0 50011731007edaa4 Normal      23        OK        OK
     [[ $l =~ ^\ +[0-9]+:[0-9] ]] && [[ ! $l =~ Normal\ +[0-9]+\ +OK\ +OK$ ]] && {
       d=$(echo $l|awk '{print $1}')
       [[ ${cage[$ca]} =~ = ]] && cage[$ca]+=",disk($d)"
       [[ ! ${cage[$ca]} =~ = ]] && cage[$ca]+="=disk($d)"
       [ $stat -eq 0 ] && stat=1
     }
  done
  unset IFS

  l=
  for c in ${cage[@]}
  do
    [[ $c =~ \= ]] && l="$l$c "
  done

   [ $stat -eq 0 ] && statexit "all cage checks have passed.|" $tf $stat
   [ $stat -ne 0 ] && statexit "some cage/s have issue/s: $l|" $tf $stat
}

[ $check == "virtvol" ] && {
  $SSH showvv > $tf || errcnt
  #tf=~/a # debug

  if [ -z "$(awk 'NF > 6 && $1 != "Id" && $8 != "normal"' $tf)" ]
  then
    statexit "all virtual volumes have normal status.|" $tf 0
  else
    statexit "virtual volumes not normal: $(awk 'NF > 6 && $1 != "Id" && $8 != "normal" {printf("%s=%s ",$2,$8)}' $tf)|" $tf 2
  fi
}


[ $check == "logdisk" ] && {
  $SSH showld > $tf || errcnt
  #tf=~/a # debug

  if [ ! -z "$(awk 'NF > 3 && $1 != "Id" && $4 != "normal"' $tf)" ]
  then
    statexit "logical disks not normal: $(awk 'NF > 3 && $1 != "Id" && $4 != "normal" {printf("vdisk%s=%s ",$1,$4)}' $tf)|" $tf 2
  else
    statexit "all logical disks have normal status.|" $tf 0
  fi
}

[ $check == "fc_sfp" ] && {
  $SSH showport -sfp |awk 'NF > 5' > $tf || errcnt
  #tf=~/a # debug

  if [ ! -z "$(awk '!/^N/ && ($2 != "OK" || $5 != "No" || $6 != "No" || $7 != "No")' $tf)" ]
  then
    statexit "fibre channel sfp fault/s detected: $(awk '!/^N/ && ($2 != "OK" || $5 != "No" || $6 != "No" || $7 != "No") {printf("nsp=%s ",$1)}' $tf)|" $tf 2
  else
    statexit "all fibre channel sfp/s ok, enabled, and without any TX or RX faults.|" $tf 0
  fi
}

# The old code was complicated. I think we will just keep it simple; if the state is not 'ready', then report it as an issue. We can always tune this later.
#
[ $check == "ports" ] && {
  $SSH showport | awk 'NF > 1' > $tf || errcnt
  #tf=~/a # debug

  if [ ! -z "$(awk '!/^N/ && $3 != "ready"' $tf)" ]
  then
    statexit "some port/s are not ready: $(awk '!/^N/ && $3 != "ready" {printf("nsp(%s)=%s ",$1,$3)}' $tf)|" $tf 2
  else
    statexit "all ports have ready status.|" $tf 0
  fi
}

[ $check == "cap" ] && {
  [ -z "$warn" ] && [ -z "$crit" ] && {
    statexit "Warning and/or critical thresholds not specified!|" $tf 1
  }

  if [ -z "$devtype" ] 
  then
    $SSH showpd > $tf || errcnt
  else
    $SSH showpd -p -devtype ${devtype^^} > $tf || errcnt 
  fi

  grep -q "No PDs listed" $tf && {
    statexit "No physical disks listed.|" $tf 1
  }

# 28 total                   73207808 50086912
  t=$(awk '$2 == "total" {print $3}' $tf)
  f=$(awk '$2 == "total" {print $4}' $tf)
  perf="used=$((($t-$f)/1024))Gb;$(($t*$warn/100/1024));$(($t*$crit/100/1024));0;$(($t/1024))"
  p=$((100-($f*100/$t)))

  [ ! -z "$crit" ] && [ $p -gt $crit ] && {
    statexit "$p% disk used > $crit%.|$perf" $tf 2
  }

  [ ! -z "$warn" ] && [ $p -gt $warn ] && {
    statexit "$p% disk used > $warn%.|$perf" $tf 1
  }

  statexit "$p% disk used.|$perf" $tf 0
}

