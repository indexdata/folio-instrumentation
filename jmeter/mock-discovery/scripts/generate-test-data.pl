#!/usr/bin/env perl

# Query a running FOLIO instance to generate appropriate test data

use strict;
use warnings;
use Getopt::Long;
use LWP;
use JSON;
use URI::Escape;

$| = 1;

# Command line
my $help = 0;
my $config_file;
GetOptions(
           'help|h' => \$help,
           'config|c=s' => \$config_file
          );
if ($help) {
  help();
  exit;
}
unless ($config_file) {
  warn "Missing required --config option\n";
  help();
  exit 1;
}
my $output_dir = $ARGV[0]?$ARGV[0]:'.';
unless (-d $output_dir) {
  warn "Output directory $output_dir not found\n";
  help();
  exit 1;
}

# config file
my $config_json = eval { slurp($config_file) };
if ($@) {
  warn "Unable to read config file: $@\n";
  help();
  exit 1;
}
my $config = eval { decode_json($config_json) };
if ($@) {
  warn "Unable to parse config file: $@\n";
  help();
  exit 1;
}

# Default CQL queries
my $instance_query = '(cql.allRecords=1)';
my $instance_count = 100000;
my $instance_set = 2147483647;

# Configuration variables
my $okapi = $$config{okapi};
my $user = $$config{user};
my $pw = $$config{password};
my $tenant = $$config{tenant};
if ($$config{instanceQuery}) {
  $instance_query .= "AND ($$config{instanceQuery})";
}
if ($$config{instanceCount}) {
  $instance_count = $$config{instanceCount};
}
if ($$config{instanceSet}) {
  $instance_set = $$config{instanceSet};
}
my $credentials_file = "$output_dir/config_random.csv";
my $instance_file = "$output_dir/instances.csv";
unless ($okapi && $user && $pw && $tenant) {
  warn "Missing required config property\n";
  help();
  exit 1;
}

my $ua = LWP::UserAgent->new();
my $header = [
              'Accept' => 'application/json, text/plain',
              'Content-Type' => 'application/json',
              'X-Okapi-Tenant' => $tenant
             ];

# Login
print "Logging in...";
my $credentials = { username => $user, password => $pw };
my $req = HTTP::Request->new('POST',"$okapi/authn/login",$header,encode_json($credentials));
my $resp = $ua->request($req);
die $resp->status_line . ":\n" . $resp->content unless $resp->is_success;
push(@{$header},( 'X-Okapi-Token' => $resp->header('X-Okapi-Token') ));
print "OK\n";

# Write the credentials file (since we know the credentials are good)
my ($okapi_protocol,$host_port_path) = split(/:\/\//,$okapi);
my ($okapi_host,$okapi_port,$path) = split(/:/,$host_port_path);
if ($path) {
  die "Path to Okapi root is not supported for Okapi URL $okapi\n";
}
unless ($okapi_protocol eq 'https' || $okapi_protocol eq 'http') {
  die "Only http or https protocols supported for Okapi URL $okapi\n";
}
unless ($okapi_port) {
  if ($okapi_protocol eq 'https') {
    $okapi_port = 443;
  } else {
    $okapi_port = 80;
  }
}
open(my $out,'>',$credentials_file)
  or die "Can't open $credentials_file: $!\n";
print $out join(',',($tenant,$user,$pw,$okapi_protocol,$okapi_host,$okapi_port)) . "\n";
close($out);
print "Wrote credentials to $credentials_file\n";

# Build instance HRID list
print "Building instance HRID list...";
my $instance_hrid_count = build_hrid_list('instance-storage/instances',$instance_query,$instance_count,$instance_file,$instance_set);
print "wrote $instance_hrid_count HRIDs to $instance_file\n";

exit;

sub build_hrid_list {
  my ($api,$query,$hrid_count,$outfile,$limit) = @_;
  $query = uri_escape($query);
  $req = HTTP::Request->new('GET',"$okapi/$api?query=$query&limit=$limit",$header);
  my @all_hrids;
  # This is not perfect, but it gets us most of the HRIDs without loading everything into memory
  # barcodes split across chunks will get dropped
  my $hrid_re = qr/"hrid":"([^"]*)"/;
  $resp = $ua->request($req,
                       sub {
                         my ($chunk,$res) = @_;
                         if ($chunk =~ /$hrid_re/m) {
                           my @hrids = ( $chunk =~ /$hrid_re/mg );
                           push(@all_hrids,@hrids);
                         }
                       });
  unless ($resp->is_success) {
    die 'Unable to retrieve HRIDs: ' . $resp->status_line . ":\n" . $resp->content . "\n";
  }
  my %hrids;
  open(my $out,">",$outfile)
    or die "Can't open $outfile: $!\n";
  my $cnt = 0;
  until (scalar(keys(%hrids)) == $hrid_count || scalar(keys(%hrids)) == scalar(@all_hrids)) {
    my $index = int(rand(scalar(@all_hrids)));
    unless ($hrids{$all_hrids[$index]}) {
      $hrids{$all_hrids[$index]} = 1;
      print $out $all_hrids[$index] . "\n";
      $cnt++;
    }
  }
  close($out);
  return($cnt);
}

sub slurp {
  my $file = shift;
  open my $fh, '<', $file or die "Unable to open $file: $!\n";
  local $/ = undef;
  my $cont = <$fh>;
  close $fh;
  return $cont;
}

sub help {
  print STDERR <<EOF;
Usage:

perl generate-test-data.pl [--help] --config <config file> [output directory]

The script will generate test data in the output directory. Instance
HRIDs in the file "instances.csv" and Okapi connection parameters in
"config_random.csv". Files with those names in the output directory
will be overwritten.

Note that the HRID parsing routine is not perfect and will not
necessarily pick up all HRIDs, depending on how the server chunks the
HTTP response.

Options:

--help | -h : Print help message.

--config | -c : Path to configuration file (required).

Configuration file:

The config file is a simple JSON file using the following format:

{
  "okapi": "[URL of Okapi server]",
  "tenant": "[Okapi tenant ID]",
  "user": "[FOLIO username]",
  "password": "[FOLIO password]",
  "instanceQuery": "[CQL query to retrieve items, optional]",
  "instanceCount": 100000,
  "instanceSet": 2147483647
}

The okapi, tenant, user, and password properties are required and
probably self-explanatory. The other properties are optional.

instanceQuery: Value should be a CQL query. It will be ANDed to the
default query "(cql.allRecords=1)".

instanceCount: The number of instances IDs to save in the
instances.csv file (default 100000).

instanceSet: The number of instances in the set retrieved from FOLIO,
which is used to randomly select instance IDs for the instances.csv
file. Default is 2147483647 (or all instances). Setting this to a
lower number will allow the script to generate the file more quickly
and using less memory, but it decreases the randomness of the test
(since only the first instanceSet instances returned by FOLIO will be
considered).
EOF
}
