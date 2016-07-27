#!/usr/bin/perl

# A Munro 05 Oct 2015: Check an oracle xe instance.
# Generates perf data so we can get graphs.
# % rounded up to a full value.
# Message made small so easier to see in Nagios.
# Rtn on output!

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use DBI;

# program base name and version
my $PROGRAM_NAME = "check_oraclexe_tablespace.pl";
my $PROGRAM_VERSION = "v1.1";

# set the ORACLE_HOME variable
my $ORACLE_HOME = "/oracle/product/11.2.0/client_1";
$ENV{ORACLE_HOME} = $ORACLE_HOME;

# seconds to wait before program exits
my $TIMEOUT = 45;

# Oracle 11G XE supports maximum of 11GB Tablespace
my $ORACLE_11GXE = 11;

# Oracle XE instances supports maximum of 4GB Tablespace
my $ORACLE_XE = 4;

# Nagios specific return values
my %retval = (
        OK => 0,
        WARNING => 1,
        CRITICAL => 2,
        UNKNOWN => 3,
);

sub usage {
        # print if there is a message supplied
        print @_ if @_;

        # print usage
        print <<"EOF";
Usage:
  ./$PROGRAM_NAME
    --connect=<Connect Identifier>
    --username=<db_user>
    --password=<db_pass>
    --warning=75%
    --critical=90%
  $PROGRAM_NAME [-h | --help]

Options:
  --connect|-H       Oracle connect identifier
  --username|-U      Oracle user
  --password|-P      Oracle user's password
  --warning|-W       The warning threshold [default: 75%]
  --critical|-C      The critical threshold [default: 95%]
  --help|-h          Display this menu and exit

EOF
        print "$PROGRAM_NAME $PROGRAM_VERSION is released under the same license as Perl v5.8.8\n" unless @_;
        exit $retval{UNKNOWN};
}

my ($db_host, $user, $pass, $warn, $crit, $help, $dbh);

# default warning and critical values if not supplied
$warn = 85 unless defined $warn;
$crit = 95 unless defined $crit;

GetOptions (
        "H|connect=s"     => \$db_host,
        "U|username=s"    => \$user,
        "P|password=s"    => \$pass,
        "W|warning=i"     => \$warn,
        "C|critical=i"    => \$crit,
        "h|help"          => \$help,
);

usage() if $help;

usage("Please specify the Oracle database identifier!\n\n") unless defined $db_host;
usage("Please specify the Oracle database user!\n\n") unless defined $user;
usage("Please specify the Oracle database user's password!\n\n") unless defined $pass;

# warning threshold should be lesser than critical
if ($warn >= $crit) {
        print "The warning threshold should be lesser than critical.  Exiting...\n";
        exit $retval{UNKNOWN};
}

# timeout handler
$SIG{'ALRM'} = sub {
        print "UNKNOWN - $PROGRAM_NAME timed out after $TIMEOUT seconds";
        exit $retval{UNKNOWN};
};

alarm $TIMEOUT;

# trying to connect to oracle database inside eval() block to catch
# Oracle specific ORA-* errors and print related message
eval {
        $dbh = DBI->connect("dbi:Oracle:$db_host", $user, $pass, { RaiseError => 1 });
};

if ($@) {
        print "CRITICAL - ORA-12154: Could not resolve $db_host" and exit $retval{CRITICAL} if ($@ =~ /ORA-12154/);
        print "CRITICAL - ORA-01017: Invalid username/password for $db_host" and exit $retval{CRITICAL} if ($@ =~ /ORA-01017/);
        print "CRITICAL - \$ORACLE_HOME is undefined" and exit $retval{CRITICAL} if ($@ =~ /OCIEnvNlsCreate.*ORACLE_HOME/i);
        print "CRITICAL - $@"; exit $retval{CRITICAL};
}

my $oracle_version = 'select version from v$instance';

my $sth = $dbh->prepare($oracle_version) or
        print "CRITICAL - $DBI::errstr" and
        exit $retval{CRITICAL};

$sth->execute() or
        print "CRITICAL - Unable to get Oracle version on $db_host" and
        exit $retval{CRITICAL};

my $row = $sth->fetchrow_array();

my $MAX_SIZE;

if ($row =~ /^11\./) {
        $MAX_SIZE = $ORACLE_11GXE;
} else {
        $MAX_SIZE = $ORACLE_XE;
}

my $query = q{select sum(user_bytes)/(1024*1024*1024)
                from dba_data_files
                where tablespace_name not in ('SYSTEM','TEMP','UNDO','UNDOTBS1')
             };

$sth = $dbh->prepare($query) or
        print "CRITICAL - $DBI::errstr" and
        exit $retval{CRITICAL};

$sth->execute() or
        print "CRITICAL - Unable to get tablespace usage on $db_host" and
        exit $retval{CRITICAL};

$row = $sth->fetchrow_array();

# job done, reset timeout
alarm 0;

# get the usage in rounded three decimal digits
$row = sprintf "%0.3f", $row;

# get the tablespace usage in percentage
my $tblspace_perc_usage = $row / $MAX_SIZE * 100;
#$tblspace_perc_usage = sprintf "%0.2f", $tblspace_perc_usage;
$tblspace_perc_usage = sprintf "%u", $tblspace_perc_usage;
$row = sprintf "%0.1f", $row;

my $msg = "$db_host tblspace use ${tblspace_perc_usage}% ($row of $MAX_SIZE Gb)";
my $perf="|\'tblspace_used\'=$tblspace_perc_usage%;$warn;$crit;;";

if ($tblspace_perc_usage >= $crit) {
#        print "CRITICAL - $msg > $crit. $msg2";
        print "CRITICAL - $msg > $crit%.$perf\n";
        exit $retval{CRITICAL};
} elsif ($tblspace_perc_usage >= $warn) {
#        print "WARNING - $msg > $warn%. $msg2";
        print "WARNING - $msg > $warn%.$perf\n";
        exit $retval{WARNING};
} else {
        print "OK - $msg$perf\n";
        exit $retval{OK};
}

__END__


