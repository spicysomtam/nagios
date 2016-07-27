#!/bin/bash

# A Munro: 23 Nov 2015: nrpe wrapper around vastool status
# Update history:
# 16 Feb 2016 A Munro: Added check for vasclnt installed. Also added support for vas versions < 4.
# 29 Mar 2016 A Munro: Make it ubuntu friendly.

breed=el
[ $(lsb_release -i|awk '{print $3}') == "Ubuntu" ] && breed=deb

[ $breed == "el" ] && {
  rpm -qi vasclnt > /dev/null 2>&1 || {
    echo "CRITICAL - VAS not installed!"
    exit 2
  }
  version=$(rpm -qi vasclnt|awk '/^Version/ {split($3,bits,"."); print bits[1]}')
}

[ $breed == "deb" ] && {
  [ -z "$(dpkg -l vasclnt 2>&1|awk '/^ii/')" ] && {
    echo "CRITICAL - VAS not installed!"
    exit 2
  }
  version=$(dpkg -l vasclnt 2>&1|awk '/^ii/ {print $3}'|cut -d. -f1)
}

if [ $version -lt 4 ]
then
  /usr/bin/sudo /opt/quest/bin/vastool status > /dev/null 2>&1 || {
    echo "CRITICAL - vastool status tests failed."
    exit 2
  }
  echo "OK - All vastool status tests passed."
  exit $err
else
  o=$(/usr/bin/sudo /opt/quest/bin/vastool status -c 2>&1) && {
    echo "OK - All vastool status tests passed."
    exit 0
  }
  err=$(echo $o|awk -F',' '{print $NF}'|sed 's/"//g')
  echo "CRITICAL - $err."
  exit 2
fi
