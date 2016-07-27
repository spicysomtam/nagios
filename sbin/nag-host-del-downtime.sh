#!/bin/sh
# This is a sample shell script showing how you can submit the DISABLE_HOST_SVC_NOTIFICATIONS command
# to Nagios.  Adjust variables to fit your environment as necessary.

now=`date +%s`
#commandfile='/usr/local/nagios/var/rw/nagios.cmd'
commandfile='/var/spool/nagios/cmd/nagios.cmd'

# Args:
# $1 downtime ID

/usr/bin/printf "[%lu] DEL_HOST_DOWNTIME;$1\n" $now > $commandfile
