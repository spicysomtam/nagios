#!/bin/sh
# This is a sample shell script showing how you can submit the DISABLE_SVC_NOTIFICATIONS command
# to Nagios.  Adjust variables to fit your environment as necessary.

now=`date +%s`
commandfile='/usr/local/nagios/var/rw/nagios.cmd'

/usr/bin/printf "[%lu] DISABLE_SVC_NOTIFICATIONS;$1;$2\n" $now > $commandfile
