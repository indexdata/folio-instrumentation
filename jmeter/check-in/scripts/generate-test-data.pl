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
my $item_query = '(barcode="" NOT barcode=="")';
my $item_count = 100000;
my $sp_query = '(cql.allRecords=1)';

# Configuration variables
my $okapi = $$config{okapi};
my $user = $$config{user};
my $pw = $$config{password};
my $tenant = $$config{tenant};
if ($$config{itemQuery}) {
  $item_query .= "AND ($$config{itemQuery})";
}
if ($$config{itemCount}) {
  $item_count = $$config{itemCount};
}
if ($$config{servicePointQuery}) {
  $sp_query .= "AND ($$config{servicePointQuery})";
}
my $credentials_file = "$output_dir/credentials.csv";
my $cki_file = "$output_dir/item_barcodes.csv";
my $sp_file = "$output_dir/service_point.csv";
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
print $out join(',',($okapi_host,$okapi_protocol,$okapi_port,$user,$pw,$tenant)) . "\n";
close($out);
print "Wrote credentials to $credentials_file\n";

# Build item barcode list
print "Building item barcode list...";
my $item_barcode_count = build_barcode_list('item-storage/items',$item_query,$item_count,$cki_file);
print "wrote $item_barcode_count barcodes to $cki_file\n";

# Build service points list
print "Building service points list...";
my $working_query = '(cql.allRecords=1)';
if ($sp_query) {
  $working_query .= " AND ($sp_query)";
}
$req = HTTP::Request->new('GET',"$okapi/service-points?query=$working_query&limit=2147483647",$header);
$resp = $ua->request($req);
die $resp->status_line . ":\n" . $resp->content unless $resp->is_success;
my $service_points = eval { decode_json($resp->content) };
if ($@) {
  die "Can't parse JSON in response:\n" . $resp->content . "\n";
}
open($out,'>',$sp_file)
  or die "Can't open $sp_file: $!\n";
my $sp_cnt = 0;
foreach my $i (@{$$service_points{servicepoints}}) {
  print $out "$$i{id}\n";
  $sp_cnt++;
}
print "$sp_cnt service points written to $sp_file\n";

exit;

sub build_barcode_list {
  my ($api,$query,$barcode_count,$outfile,$limit) = @_;
  $limit = 2147483647 unless $limit;
  $query = uri_escape($query);
  $req = HTTP::Request->new('GET',"$okapi/$api?query=$query&limit=$limit",$header);
  my @all_barcodes;
  # This is not perfect, but it gets us most of the barcodes without loading everything into memory
  # barcodes split across chunks will get dropped
  my $bc_re = qr/"barcode":"([^"]*)"/;
  $resp = $ua->request($req,
                       sub {
                         my ($chunk,$res) = @_;
                         if ($chunk =~ /$bc_re/m) {
                           my @bcs = ( $chunk =~ /$bc_re/mg );
                           push(@all_barcodes,@bcs);
                         }
                       });
  unless ($resp->is_success) {
    die 'Unable to retrieve barcodes: ' . $resp->status_line . ":\n" . $resp->content . "\n";
  }
  my %barcodes;
  open(my $out,">",$outfile)
    or die "Can't open $outfile: $!\n";
  my $cnt = 0;
  until (scalar(keys(%barcodes)) == $barcode_count || scalar(keys(%barcodes)) == scalar(@all_barcodes)) {
    my $index = int(rand(scalar(@all_barcodes)));
    unless ($barcodes{$all_barcodes[$index]}) {
      $barcodes{$all_barcodes[$index]} = 1;
      print $out $all_barcodes[$index] . "\n";
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

The script will generate test data in the output directory. Item
barcodes in the file "item_barcodes.csv" service points in
"service_point.csv", and Okapi connection parameters in
"credentials.csv". Files with those names in the output directory will
be overwritten.

Note that the barcode parsing routine is not perfect and will not
necessarily pick up all barcodes, depending on how the server chunks
the HTTP response.

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
  "itemQuery": "[CQL query to retrieve items, optional]",
  "itemCount": 100000,
  "servicePointQuery": "[CQL query to retrieve service points, optional]"
}

The okapi, tenant, user, and password properties are required. The
other properties are optional. Any CQL queries are ANDed to the
default queries (see below). The defaults for other optional
properties are as shown above.

Default itemQuery: (barcode="" NOT barcode=="")
Default servicePointQuery: (cql.allRecords=1)

To limit the test data to items that are checked out, use
status.name=="Checked out" as the itemQuery.
EOF
}
