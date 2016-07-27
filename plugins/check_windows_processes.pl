#!/usr/bin/perl
# A Munro: This checks for a process rather than a service, and it expects the process to be lowercase (eg omninet.exe). 
# See check_snmp_win_service.pl for checking services.

# nagios: -epn

use strict;
use warnings;
use Getopt::Std;
use Net::SNMP;

my $program_name = "check_windows_processes";
my $program_version = "v0.1b";
my $timeout = 60;

# snmptranslate -On hrSWRunName
my $oid_proclist = '.1.3.6.1.2.1.25.4.2.1.2';

# Nagios specific return values
my $retval = {
        OK => 0,
        WARNING => 1,
        CRITICAL => 2,
        UNKNOWN => 3
};

sub usage {
        my $msg = shift;
        print $msg if $msg;
        print <<"EOF";
Usage: $program_name -H <hostname|ip address> -C <SNMP community> -P <process1,process2,process3...>

  -H    Hostname or IP address of the monitored host
  -C    SNMP Community
  -P    Comma separated list of Windows processes to check
  -l	Long output, includes process names and instance count
  -f 	Include performance data to generate graphs
  -h 	Display this help and exit

EOF
        exit $retval->{UNKNOWN};
}

my %opts;

# populate command line options
getopts('H:C:P:fl', \%opts);

usage if defined $opts{h};
usage("Enter a hostname or an IP!\n") unless defined $opts{H};
usage("Enter SNMP community!\n") unless defined $opts{C};
usage("Enter Windows process list!\n") unless defined $opts{P};

my $hostname = $opts{H};     # windows host name
my $community = $opts{C};    # $E<RE7
my $proc_list = $opts{P};    # svchost.exe,dllhost.exe,explorer.exe
my $flag_perf_data = $opts{f};		# flag for performance data
my $flag_long_output = $opts{l};	# flag for longer output

my @processes = split /,\s*/, lc $proc_list;

my %angoor;
@angoor{@processes} = ();

# timeout handler
$SIG{ALRM} = sub {
        print "UNKNOWN - Connection timed out.  You may want to increase timeout value (current: $timeout)";
        exit $retval->{UNKNOWN};
};

alarm $timeout;

# create a new session
my ($session, $error) = Net::SNMP->session (
        -hostname => $hostname,
        -community => $community,
	-timeout => $timeout,
);

unless (defined $session) { 
	print "CRITICAL - $error";
	exit $retval->{CRITICAL};
}

my $result;
my @all_processes;

if (defined ($result = $session->get_table(-baseoid => $oid_proclist))) {
	for ($session->var_bind_names()) {
		push @all_processes, lc $result->{"$_"};
	}
} else {
	print "CRITICAL - ", $session->error();
	exit $retval->{CRITICAL};
}

$session->close();

# reset timeout alarm
alarm 0;

for my $p (@all_processes) {
	if (exists ($angoor{$p})) {
		$angoor{$p}++;
	}
}

my @missing = grep { ! defined $angoor{$_} } sort keys %angoor;
my ($msg, $perf_data);

for my $k (keys %angoor) {
	if (defined $angoor{$k}) {
		$perf_data .= "$k=$angoor{$k};;0;; ";
	} else {
		$perf_data .= "$k=0;;0;; ";
	}
}

if (@missing) {
	$msg = "CRITICAL: ";
	$msg .= scalar @missing == 1 ? "Process " : "Processes ";
	$msg .= join ", ", @missing;
	$msg .= " not running";
	$msg .= " | $perf_data" if $flag_perf_data;
	print $msg;
	exit $retval->{CRITICAL};
} else {
	if ($flag_long_output) {
		$msg = "OK: ";
		$msg .= scalar @processes == 1 ? "Process " : "Processes ";
		$msg .= join ", ", map { "$_($angoor{$_})" } keys %angoor if $flag_long_output;
		$msg .= " are running";
	} else {
		$msg = "Processes OK";
	}
	$msg .= " | $perf_data" if $flag_perf_data;
	print $msg."\n";
	exit $retval->{OK};
}
