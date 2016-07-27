#!/bin/bash

# A Munro: 19 Apr 2016: schedule downtimes based on a passed filename or hostname.

# Args:
# $1: hostname or .lis filename.
# $2: start time; any value accepted by the date command. eg "now", "tomorrow", ="13 Feb 2016 01:00"
# $3: end time; same as start time but later!
# $4: downtime comment
# $5: author. Your AD username

[[ $1 =~ ^-(|-)h ]] && {
  echo "$(basename $0) <.lis file>|<hostname> \"start-time\" \"end-time\" \"comment\" <ad-user>"
  echo "  Times are anything the date command accepts. examples: now, tomorrow, \"13 Feb 2016 01:00\""
  echo ""
  exit 0
}

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

[ -z "$4" ] && {
  echo Downtime comment must be passed as arg 4.
  exit 1
}

[ -z "$5" ] && {
  echo Username must be passed as arg 5.
  exit 1
}


stm=$(date "+%s" --date="$2") || exit 1
etm=$(date "+%s" --date="$3") || exit 1

[ $etm -le $stm ] && {
  echo End time must be later than start time!
  exit 1
}

for i in ${h[@]}
do
  echo Setting downtimes for $i...
  #echo y|pynag downtime $i --comment="$4" --start_time=$stm --end_time=$etm --recursive --author=$5
  # pynag is not consistent with setting the host downtime; lets do it the nagios cmd interface way
  # Also it adds service downtime duplicates, which adds up to alot of entries when doing a DC/site
  # So do the service and host downtimes using this, which is way faster than pynag.
  /usr/bin/printf "[%lu] SCHEDULE_HOST_DOWNTIME;$i;$stm;$etm;1;0;7200;$5;$4\n" $(date +%s) > /var/spool/nagios/cmd/nagios.cmd
  /usr/bin/printf "[%lu] SCHEDULE_HOST_SVC_DOWNTIME;$i;$stm;$etm;1;0;7200;$5;$4\n" $(date +%s) > /var/spool/nagios/cmd/nagios.cmd
done
