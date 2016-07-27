#!/bin/bash

[ -z "$1" ] && { \
  echo "Hostname as arg1"
  exit 1
}

[ -z "$2" ] && { \
  echo "Hostgroup as arg2"
  exit 1
}

okconfig install $1 --ssh --user root
okconfig addhost $1 --template linux --group $2
#okconfig addhost $1 --group $2
/usr/lib64/nagios/sbin/nag-disable-all-host-services.sh $1
echo ""
