#!/bin/bash

# A Munro: 11 Jul 2016
# Delete old pnp4nagios rrdfiles that are x number of days old or older.
# This will also fix rrd files that are not updating because of mismatched
# number of data sources or other errors.
# 
days=10 # should be long enough for any system with a long term fault!

echo "Starting at $(date)"

echo rrd files deleted:
find /var/lib/pnp4nagios -name "*.rrd" -mtime +$days -ls -exec rm -f {} \;

echo "Completed at $(date)"
