#!/bin/sh
# This is a sample shell script showing how you can submit the DISABLE_HOST_SVC_NOTIFICATIONS command
# to Nagios.  Adjust variables to fit your environment as necessary.
# SCHEDULE_FORCED_SVC_CHECK;<host_name>;<service_description>;<check_time>

now=`date +%s`
#commandfile='/usr/local/nagios/var/rw/nagios.cmd'
commandfile='/var/spool/nagios/cmd/nagios.cmd'

/usr/bin/printf "[%lu] SCHEDULE_FORCED_SVC_CHECK;$1;$2;1110741500\n" $now > $commandfile
