#!/bin/bash

# A Munro: script to check mount point. That a filesystem is mounted and the mount point can be read.
# timeout is a nice feature in case of hangs. It was originally written to check stornext cvfs filesystems
# which can hang when queried. However can be used for any mount such as a non autofs nfs mount.

# $1 is the mount eg /filesystem
# $2 is the timeoute; optional; if not specified default is 5s.

tmout=5s
[ ! -z "$2" ] && tmout=$2

timeout $tmout mountpoint $1 > /dev/null 2>&1 || { 
  echo "CRITICAL $1 not mounted."
  exit 2
}

timeout $tmout ls -l $1/ > /dev/null 2>&1 || { 
  echo "CRITICAL $1 cannot read."
  exit 2
}

[ ! -z "$(ls -l $1|awk '/^d/{print $NF}'|head -1)" ] && {
  sd=$(ls -l $1|awk '/^d/{print $NF}'|head -1)

  timeout $tmout ls -l $1/$sd/ > /dev/null 2>&1 || { 
    echo "CRITICAL $1 cannot read from sub directories."
    exit 2
  }
}

echo "OK $1 mounted and readable."
exit 0
