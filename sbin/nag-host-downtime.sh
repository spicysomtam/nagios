#!/bin/sh
# This is a sample shell script showing how you can submit the DISABLE_HOST_SVC_NOTIFICATIONS command
# to Nagios.  Adjust variables to fit your environment as necessary.

now=`date +%s`
#commandfile='/usr/local/nagios/var/rw/nagios.cmd'
commandfile='/var/spool/nagios/cmd/nagios.cmd'

# Args:
# $1 hostname
# $2 start_time
# $3 end_time 
# $4 author
# $5 comment
# SCHEDULE_HOST_DOWNTIME;<host_name>;<start_time>;<end_time>;<fixed>;<trigger_id>;<duration>;<author>;<comment>

#/usr/bin/printf "[%lu] SCHEDULE_HOST_DOWNTIME;$1;1110741500;1110748700;0;0;7200;alastirm;US DC Outage\n" $now > $commandfile
/usr/bin/printf "[%lu] SCHEDULE_HOST_DOWNTIME;$1;$2;$3;0;0;7200;$4;$5\n" $now > $commandfile
