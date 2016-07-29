#! /usr/bin/perl -w

# Author: Martin Fuerstenau, Oce Printing Systems
#         martin.fuerstenau_at_oce.com or Martin.fuerstenau_at_nagiossw.org
#
# Date:   23 Jul 2011
# 
#
# Purpose and features of the program:
#
# - Get the network usage for Windows, Solaris and Linux servers.
#
# History and Changes:
# 
# - 23 Jul 2011 Version 1
#    - First released version
#
# - 29 Sep 2011 Version 1.1
#   - Corrected minor bug (String xxx in output)
#   - Enhanced for NetApp network interfaces
#
# - 9 Oct 2012 Version 1.2
#   - Corrections for Windows 2012 server.
#
# - 27 Aug 2015 A Munro (alastair@alastair-munro.com)
#   Added the --notraffic and --match args. So we can skip no traffic interfaces and pattern match on the interface name using a regex. 
#   The notraffic arg also prevents supurious alerts when not in use interfaces are down and -b is specified.
#   Also sorted the output on interface name order; rather than being jumbled up. This makes bond interfaces display before eth interfaces; 
#   it just makes much more sense as a bond interface is typically made up of several eth interfaces. 
#   So we would see: OK. bond0:up eth0:up eth1:up eth2:up eth3:up eth4:up eth5:up
#   Was tempted to merge the duplicate blocks of code into one; but its not my script and it would take some effort.


use strict;
use Getopt::Long;
use Net::SNMP;

my $ProgName = "check_int_traffic";
my $help; 
my $hostname;                                 # hostname 
my $host;                                     # Valid hostname
my $snmpport;                                 # SNMP port
my $snmpport_def = "161";                     # SNMP port default
my $os;                                       # To store the operating system name

 
my $sysDescr;                                 # Contains the system description. Needed to decide
                                              # whether it is Solaris, a Linux or Windows
my $sysObject;                                # $sysObject and $sysObjectID are needed for Linux
my $sysObjectID;                              # only to determine whether it is an old ucd-snmp or net-snmp
my $ucdintcnt = 0;                            # Interface counter f. ucd-snmp. ucd-snmp doesn't report
                                              # eth0, eth1 etc.. It reports only eth. But we need a unique
                                              # name. So as a workaround this counter is added

my $out;                                      # Contains the output
my $perfout;                                  # Contains the performance output

my $firstloop = 0;                            # To determine whether it is the first loop run or not

my $IntIdx;                                   # Interface Index
my $IntDescr;                                 # Contains the interface name (description)
my $oid2descr;                                # Gets the result of the get_table for description
my $descr_oid = '1.3.6.1.2.1.2.2.1.2';        # Base OID for description

my $in_octet;                                 # Contains the incoming octets
my $oid2in_octet;                             # Gets the result of the get_table for incoming octets
my $in_octet_oid = '1.3.6.1.2.1.2.2.1.10';    # Base OID for description

my $out_octet;                                # Contains the outgoing octets
my $oid2out_octet;                            # Gets the result of the get_table for outgoing octets
my $out_octet_oid = '1.3.6.1.2.1.2.2.1.16';   # Base OID for description

my $oper;                                     # Contains the interface operational status
my $oid2oper;                                 # Gets the result of the get_table for operational status
my $oper_oid = '1.3.6.1.2.1.2.2.1.8';         # Base OID for description


my %InterfaceStat = (
                    "1" => "up",
                    "2" => "down",
                    "3" => "testing",
                    "4" => "unknown",
                    "5" => "dormant",
                    "6" => "notPresent",
                    "7" => "lowerLayerDown"
                    );                        # Get the operational status of the interface Enumerations:
my ($session,$error);                         # Needed to establish the session
my $key;                                      # Needed in the loops. Contains various OIDs
my $snmpversion;                              # SNMP version
my $snmpversion_def = 1;                      # SNMP version default
my $community;                                # community 
my $oid2get;                                  # To store the OIDs
my $IntDownAlert;                             # Alarm if interface is down. Default is no alarm
my $IsDown = 0;                               # Used in loop. Switched to 1 if a interface is down
my $NoTraffic;                                # Skip interfaces with no in/out packet counts; default don't skip.
my $ifregex;                                  # Interface pattern match.


$ENV{'PATH'}='';
$ENV{'BASH_ENV'}=''; 
$ENV{'ENV'}='';

# Start of the main routine

Getopt::Long::Configure('bundling');
GetOptions
	("h"   => \$help,          "help"          => \$help,
	 "v=s" => \$snmpversion,   "snmpversion=s" => \$snmpversion,
	 "m=s" => \$ifregex,       "match=s"       => \$ifregex,
	 "d" =>   \$IntDownAlert,  "down"          => \$IntDownAlert,
	 "n" =>   \$NoTraffic,     "notraffic"     => \$NoTraffic,
	 "H=s" => \$hostname,      "hostname=s"    => \$hostname,
	 "C=s" => \$community,     "community=s"   => \$community,
	 "p=s" => \$snmpport,      "port=s"        => \$snmpport);

if ($help)
   {
   print_help();
   exit 0;
   }

if (!$hostname)
    {
    print "Host name/address not specified\n\n";
    print_usage();
    exit 3;
    }

if ($hostname =~ /([-.A-Za-z0-9]+)/)
   {
   $host = $1;
   }

if (!$host)
    {
    print "Invalid host: $hostname\n\n";
    print_usage();
    exit 3;
    }

if (!$community)
   {
   $community = "public";
   }

if (!$IntDownAlert)
   {
   # 0 = No alarm
   # 1 = Alarm if an interface is down
   $IntDownAlert = 0;
   }

if (!$NoTraffic)
   {
   # 0 = Don't skip no counter interfaces
   # 1 = Skip no counter interfaces
   $NoTraffic= 0;
   }

if (!$snmpversion)
   {
   $snmpversion = $snmpversion_def;
   }

if (!$snmpport)
   {
   $snmpport = $snmpport_def;
   }

if (!($snmpversion eq "1" || $snmpversion eq "2"))
   {
   print "\nError! Only SNMP V1 or 2 supported!\n";
   print "Wrong version submitted.\n";
   print_usage();
   exit 3;
   }

# --------------- Begin main subroutine ----------------------------------------

# We initialize the snmp connection

($session, $error) = Net::SNMP->session( -hostname  => $hostname,
                                         -version   => $snmpversion,
                                         -community => $community,
                                         -port      => $snmpport,
                                         -retries   => 10,
                                         -timeout   => 10
                                        );


# If there is something wrong...exit

if (!defined($session))
   {
   printf("ERROR: %s.\n", $error);
   exit 3;
   }

# Get rid of UTF8 translation in case of accentuated caracters
$session->translate(Net::SNMP->TRANSLATE_NONE);

# Get the operating system

$oid2get = ".1.3.6.1.2.1.1.1.0";

$sysDescr = $session->get_request( -varbindlist => ["$oid2get"] );

$os = $$sysDescr{$oid2get};
$os =~ s/^.*Software://;
$os =~ s/^\s+//;
$os =~ s/ .*//;


# Get all interface tables

$oid2descr = $session->get_table( -baseoid =>  $descr_oid );
$oid2in_octet = $session->get_table( -baseoid =>  $in_octet_oid );
$oid2out_octet = $session->get_table( -baseoid =>  $out_octet_oid );
$oid2oper = $session->get_table( -baseoid =>  $oper_oid );

 
if ( $os eq "NetApp" )
   {

   # Because ucd list only eth (or so) without a number (like eth0) we
   # have to determine wether it is ucd (2021) or net-snmp (8072) so we can
   # set up a counter to generate this information
   
   $oid2get = ".1.3.6.1.2.1.1.2.0";
   $sysObject = $session->get_request( -varbindlist => ["$oid2get"] );
   $sysObjectID = $$sysObject{$oid2get};
   $sysObjectID =~ s/^\.1\.3\.6\.1\.4\.1\.//;
   $sysObjectID =~ s/\..*$//;

   foreach $key ( keys %$oid2descr)
          {

          # Monitoring traffic on a loopback interface doesn't make sense
          if ($$oid2descr{$key} =~ m/lo.*$/isog)
             {
             delete $$oid2descr{$key};
             }
          else
             {
             # This is a little bit tricky. If we have deleted the loopback interface
             # during this run of the loop $key is not set. Therefore the if-statement
             # will cause an error because $key is not initialized. So we first have to check
             # it is :-))
          
             # Kick out any sit interface
             if ($$oid2descr{$key} =~ m/vh.*$/isog)
                {
                delete $$oid2descr{$key};
                }
             }
          }

   # 0 = No alarm
   # 1 = Alarm if an interface is down
   # $IntDownAlert;                           # Alarm if interface is down. Default is no alarm
   # $IsDown = 0;                             # Used in loop. Switched to 1 if a interface is down

   foreach $key ( sort { $$oid2descr{$a} cmp $$oid2descr{$b} } keys %$oid2descr)
          {
          $IntIdx = $key;
          $IntIdx =~ s/^.*\.//;
          
          if ( $sysObjectID == 2021 )
             {
             $$oid2descr{$key} = $$oid2descr{$key}.$ucdintcnt;
             $ucdintcnt++;
             }
          # Get the incoming octets
          $oid2get = $in_octet_oid.".".$IntIdx;
          $in_octet = $$oid2in_octet{$oid2get};
          
          # Get the outgoing octets
          $oid2get = $out_octet_oid.".".$IntIdx;
          $out_octet = $$oid2out_octet{$oid2get};

          if ($in_octet == 0 and $out_octet == 0 and $NoTraffic == 1) { next }

          # Get the operational status of the interface
          # Enumerations:
          # 1 - up
          # 2 - down
          # 3 - testing
          # 4 - unknown
          # 5 - dormant
          # 6 - notPresent
          # 7 - lowerLayerDown
          
          $oid2get = $oper_oid.".".$IntIdx;
          $oper = $$oid2oper{$oid2get};
          $IntDescr = $$oid2descr{$key};

          if ($ifregex ne "" and $IntDescr !~ $ifregex) { next }

          if ( $IntDownAlert == 1 )
             {
             if ( $oper != 1 )
                {
                $IsDown = 1;
                }
             }

          if ( $firstloop == 0 )
             {
             $firstloop = 1;
             $IntDescr =~ s/\0//isog;
             $out = $IntDescr . ":" . $InterfaceStat{$oper};
             $perfout = "'" . $IntDescr . "_in_octet'=" . $in_octet . "c '" . $IntDescr . "_out_octet'=" . $out_octet . "c";
             }
          else
             {
             $IntDescr =~ s/\0//isog;
             $out .= " " . $IntDescr . ":" . $InterfaceStat{$oper};
             $perfout .= "  '" . $IntDescr . "_in_octet'=" . $in_octet . "c '" . $IntDescr . "_out_octet'=" . $out_octet . "c";
             }
          }

   if ( $IsDown == 1 )
      {
      print "Critical! $out";
      print " | $perfout\n";
      exit 2;
      }
   else
      {
      print "OK. $out";
      print " | $perfout\n";
      exit 0;
      }

   }


if ( $os eq "Linux" )
   {

   # Because ucd list only eth (or so) without a number (like eth0) we
   # have to determine wether it is ucd (2021) or net-snmp (8072) so we can
   # set up a counter to generate this information
   
   $oid2get = ".1.3.6.1.2.1.1.2.0";
   $sysObject = $session->get_request( -varbindlist => ["$oid2get"] );
   $sysObjectID = $$sysObject{$oid2get};
   $sysObjectID =~ s/^\.1\.3\.6\.1\.4\.1\.//;
   $sysObjectID =~ s/\..*$//;

   foreach $key ( keys %$oid2descr)
          {

          # Monitoring traffic on a loopback interface doesn't make sense
          if ($key =~ m/^.*\.1$/)
             {
             delete $$oid2descr{$key};
             }
          else
             {
             # This is a little bit tricky. If we have deleted the loopback interface
             # during this run of the loop $key is not set. Therefore the if-statement
             # will cause an error because $key is not initialized. So we first have to check
             # it is :-))
          
             # Kick out any sit interface
             if ($$oid2descr{$key} =~ m/sit.*$/isog)
                {
                delete $$oid2descr{$key};
                }
             }
          }

   # 0 = No alarm
   # 1 = Alarm if an interface is down
   # $IntDownAlert;                           # Alarm if interface is down. Default is no alarm
   # $IsDown = 0;                             # Used in loop. Switched to 1 if a interface is down


   foreach $key ( sort { $$oid2descr{$a} cmp $$oid2descr{$b} } keys %$oid2descr)
          {
          $IntIdx = $key;
          $IntIdx =~ s/^.*\.//;
          
          if ( $sysObjectID == 2021 )
             {
             $$oid2descr{$key} = $$oid2descr{$key}.$ucdintcnt;
             $ucdintcnt++;
             }
          # Get the incoming octets
          $oid2get = $in_octet_oid.".".$IntIdx;
          $in_octet = $$oid2in_octet{$oid2get};
          
          # Get the outgoing octets
          $oid2get = $out_octet_oid.".".$IntIdx;
          $out_octet = $$oid2out_octet{$oid2get};

          if ($in_octet == 0 and $out_octet == 0 and $NoTraffic == 1) { next }

          # Get the operational status of the interface
          # Enumerations:
          # 1 - up
          # 2 - down
          # 3 - testing
          # 4 - unknown
          # 5 - dormant
          # 6 - notPresent
          # 7 - lowerLayerDown
          
          $oid2get = $oper_oid.".".$IntIdx;
          $oper = $$oid2oper{$oid2get};
          $IntDescr = $$oid2descr{$key};

          if (defined($ifregex) and $IntDescr !~ $ifregex) { next }

          if ( $IntDownAlert == 1 )
             {
             if ( $oper != 1 )
                {
                $IsDown = 1;
                }
             }

          if ( $firstloop == 0 )
             {
             $firstloop = 1;
             $IntDescr =~ s/\0//isog;
             $out = $IntDescr . ":" . $InterfaceStat{$oper};
             $perfout = "'" . $IntDescr . "_in_octet'=" . $in_octet . "c '" . $IntDescr . "_out_octet'=" . $out_octet . "c";
             }
          else
             {
             $IntDescr =~ s/\0//isog;
             $out .= " " . $IntDescr . ":" . $InterfaceStat{$oper};
             $perfout .= "  '" . $IntDescr . "_in_octet'=" . $in_octet . "c '" . $IntDescr . "_out_octet'=" . $out_octet . "c";
             }
          }

   if ( $IsDown == 1 )
      {
      print "Critical! $out";
      print " | $perfout\n";
      exit 2;
      }
   else
      {
      print "OK. $out";
      print " | $perfout\n";
      exit 0;
      }

   }


if ( $os eq "SunOS" )
   {
   foreach $key ( keys %$oid2descr)
          {
          # Monitoring traffic on a loopback interface doesn't make sense
          if ($key =~ m/^.*\.1$/)
             {
             delete $$oid2descr{$key};
             }
          }

   foreach $key ( sort { $$oid2descr{$a} cmp $$oid2descr{$b} } keys %$oid2descr)
          {
          $IntIdx = $key;
          $IntIdx =~ s/^.*\.//;

          # Get the incoming octets
          $oid2get = $in_octet_oid.".".$IntIdx;
          $in_octet = $$oid2in_octet{$oid2get};
          
          # Get the outgoing octets
          $oid2get = $out_octet_oid.".".$IntIdx;
          $out_octet = $$oid2out_octet{$oid2get};

          if ($in_octet == 0 and $out_octet == 0 and $NoTraffic == 1) { next }

          # Get the operational status of the interface
          # Enumerations:
          # 1 - up
          # 2 - down
          # 3 - testing
          # 4 - unknown
          # 5 - dormant
          # 6 - notPresent
          # 7 - lowerLayerDown
          
          $oid2get = $oper_oid.".".$IntIdx;
          $oper = $$oid2oper{$oid2get};
          $IntDescr = $$oid2descr{$key};

          if ($ifregex ne "" and $IntDescr !~ $ifregex) { next }

          if ( $IntDownAlert == 1 )
             {
             if ( $oper != 1 )
                {
                $IsDown = 1;
                }
             }

          if ( $firstloop == 0 )
             {
             $firstloop = 1;
             $IntDescr =~ s/\0//isog;
             $out = $IntDescr . ":" . $InterfaceStat{$oper};
             $perfout = "'" . $IntDescr . "_in_octet'=" . $in_octet . "c '" . $IntDescr . "_out_octet'=" . $out_octet . "c";
             }
          else
             {
             $IntDescr =~ s/\0//isog;
             $out .= " " . $IntDescr . ":" . $InterfaceStat{$oper};
             $perfout .= "  '" . $IntDescr . "_in_octet'=" . $in_octet . "c '" . $IntDescr . "_out_octet'=" . $out_octet . "c";
             }
          }

   if ( $IsDown == 1 )
      {
      print "Critical! $out";
      print " | $perfout\n";
      exit 2;
      }
   else
      {
      print "OK. $out";
      print " | $perfout\n";
      exit 0;
      }

   }


if ( $os eq "Windows" )
   {
   foreach $key ( keys %$oid2descr)
          {
          # Monitoring traffic on a loopback interface doesn't make sense
          if ($key =~ m/^.*\.1$/)
             {
             delete $$oid2descr{$key};
             }

          if ($$oid2descr{$key})
             {
             if ($$oid2descr{$key} =~ m/^WAN.*$/)
                {
                delete $$oid2descr{$key};
                }
             }

          if ($$oid2descr{$key})
             {
             if ($$oid2descr{$key} =~ m/^RAS.*$/)
                {
                delete $$oid2descr{$key};
                }
             }

          if ($$oid2descr{$key})
             {
             if ($$oid2descr{$key} =~ m/^.*LightWeight Filter.*$/)
                {
                delete $$oid2descr{$key};
                }
             }

          if ($$oid2descr{$key})
             {
             if ($$oid2descr{$key} =~ m/^.*QoS Packet Scheduler.*$/)
                {
                delete $$oid2descr{$key};
                }
             }

          if ($$oid2descr{$key})
             {
             if ($$oid2descr{$key} =~ m/^Microsoft ISATAP Adapter.*$/)
                {
                delete $$oid2descr{$key};
                }
             }

          if ($$oid2descr{$key})
             {
             if ($$oid2descr{$key} =~ m/^Microsoft Network Adapter.*$/)
                {
                delete $$oid2descr{$key};
                }
             }

          if ($$oid2descr{$key})
             {
             if ($$oid2descr{$key} =~ m/^Microsoft Debug Adapter.*$/)
                {
                delete $$oid2descr{$key};
                }
             }


          if ($$oid2descr{$key})
             {
             if ($$oid2descr{$key} =~ m/^Microsoft Kernel Debug.*$/)
                {
                delete $$oid2descr{$key};
                }
             }

          if ($$oid2descr{$key})
             {
             if ($$oid2descr{$key} =~ m/^.*Pseudo-Interface.*$/)
                {
                delete $$oid2descr{$key};
                }
             }
          }

   foreach $key ( sort { $$oid2descr{$a} cmp $$oid2descr{$b} } keys %$oid2descr)
          {
          $IntIdx = $key;
          $IntIdx =~ s/^.*\.//;

          # Get the incoming octets
          $oid2get = $in_octet_oid.".".$IntIdx;
          $in_octet = $$oid2in_octet{$oid2get};
          
          # Get the outgoing octets
          $oid2get = $out_octet_oid.".".$IntIdx;
          $out_octet = $$oid2out_octet{$oid2get};

          if ($in_octet == 0 and $out_octet == 0 and $NoTraffic == 1) { next }

          # Get the operational status of the interface
          # Enumerations:
          # 1 - up
          # 2 - down
          # 3 - testing
          # 4 - unknown
          # 5 - dormant
          # 6 - notPresent
          # 7 - lowerLayerDown
          
          $oid2get = $oper_oid.".".$IntIdx;
          $oper = $$oid2oper{$oid2get};
          $IntDescr = $$oid2descr{$key};

          if ($ifregex ne "" and $IntDescr !~ $ifregex) { next }

          if ( $IntDownAlert == 1 )
             {
             if ( $oper != 1 )
                {
                $IsDown = 1;
                }
             }

          if ( $firstloop == 0 )
             {
             $firstloop = 1;
             $IntDescr =~ s/\0//isog;
             $out = $IntDescr . ":" . $InterfaceStat{$oper};
             $perfout = "'" . $IntDescr . "_in_octet'=" . $in_octet . "c '" . $IntDescr . "_out_octet'=" . $out_octet . "c";
             }
          else
             {
             $IntDescr =~ s/\0//isog;
             $out .= " " . $IntDescr . ":" . $InterfaceStat{$oper};
             $perfout .= "  '" . $IntDescr . "_in_octet'=" . $in_octet . "c '" . $IntDescr . "_out_octet'=" . $out_octet . "c";
             }
          }

   if ( $IsDown == 1 )
      {
      print "Critical! $out";
      print " | $perfout\n";
      exit 2;
      }
   else
      {
      print "OK. $out";
      print " | $perfout\n";
      exit 0;
      }

   }

# Not kicked out yet? So it seems to unknown
exit 3;

# --------------- Begin subroutines ----------------------------------------

sub print_usage
    {
    print "\nUsage: $ProgName -H <host> [-C community] [-d]\n\n";
    print "or\n";
    print "\nUsage: $ProgName -h for help.\n\n";
    }

sub print_help
    {
    print "$ProgName,Version 1.0\n";
    print "Copyright (c) 2011 Martin Fuerstenau - Oce Printing Systems\n";
    print_usage();
    print "    -H, --hostname=HOST            Name or IP address of host to check\n";
    print "    -C, --community=community      SNMP community (default public)\n\n";
    print "    -v, --snmpversion=snmpversion  Version of the SNMP protocol. At present version 1 or 2c\n\n";
    print "    -p, --portsnmpversion=snmpversion  Version of the SNMP protocol. At present version 1 or 2c\n\n";
    print "    -d, --down                     Alarm if any of the interfaces is down\n\n";
    print "    -n, --notraffic                Ignore interfaces not used (in/out counters are zero)\n\n";
    print "    -m, --match [regex]            Pattern match interface names. eg (bond0|eth(0|1))\n\n";
    print "    -h, --help Short help message\n\n";
    print "\n";
    }
