# JMeter performance test for check in

This test exercises a FOLIO backend system by performing the API calls used by the UI for check in. It is based on the [check-in-check-out](https://github.com/folio-org/perf-testing/tree/master/workflows-scripts/circulation/check-in-check-out) script in the FOLIO [perf-testing](https://github.com/folio-org/perf-testing) repository and uses many of the conventions from those tests.

## Test notes

* The test emulates a FOLIO user logging in, then performing a sequence of check ins until the test time expires. At various points in the test, a random delay is introduced to emulate what might be typical pauses in the workflow.
* If the barcodes in the `checked_out.csv` file (see [Test data](#test-data) below) are exhausted before test time expires, the test will end.
* It is probably most realistic if the test items are checked out, but this is not actually required. Items that are not checked out (have no open loans) put a lighter load on the system.
* The test is targeted at a Honeysuckle FOLIO environment.

## Test data

The following data files in the `jmeter-supported-data` directory are needed to support the Jmeter script during its execution. 

- `credentials.csv`: a file to specify connection information and credentials for the tenant being tested. Format: `[Okapi hostname],[Okapi protocol],[Okapi port],[FOLIO username],[FOLIO password],[tenant ID]`. Default for protocol is http, default port is 80 (443 for https).
- `item_barcodes.csv`: a list of item barcodes to check in.
- `service_point.csv`: a list of one or more service points to use for check out.

Test data can be generated using the [test data script](#preparing-the-test-data), see below.

## User properties

The test can be configured using the following user properties (set in a properties file or with the `--jmeterproperty | -J` command line option). They can also be configured using the "User Defined Variables" component in the JMeter console:

- `VUSERS`: the number of users to emulate, default 10
- `RAMP_UP`: the ramp-up period in seconds, default 1
- `DURATION`: how long to run the test in seconds, default 300
- `THINK_OFFSET`: additional wait time between checkouts in milliseconds, default 0 (note that there is already a 5-7 second delay between checkouts, this is an additional offset)

## Preparing the test data

You can prepare a set of test data from a FOLIO environment using the [scripts/generate-test-data.pl](scripts/generate-test-data.pl) script. The script will generate all the required test data files in the output directory. Any files with those names in the output directory will be overwritten.

Note that the barcode parsing routine is not perfect and will not necessarily pick up all barcodes, depending on how the server chunks the HTTP response.

### Usage

    perl generate-test-data.pl [--help] --config <config file> <output directory>

### Options

- `--help | -h`: Print help message.
- `--config | -c`: Path to configuration file (**required**).

### Configuration file

The config file is a simple JSON file using the following format:

```json
{
  "okapi": "[URL of Okapi server]",
  "tenant": "[Okapi tenant ID]",
  "user": "[FOLIO username]",
  "password": "[FOLIO password]",
  "itemQuery": "[CQL query to retrieve items, optional]",
  "itemCount": 100000,
  "servicePointQuery": "[CQL query to retrieve service points, optional]"
}
```

The `okapi`, `tenant`, `user`, and `password` properties are required. The other properties are optional. Any CQL queries are ANDed to the default queries (see below). The defaults for other optional properties are as shown above.

Default itemQuery: `(barcode="" NOT barcode=="")` 

Default servicePointQuery: `(cql.allRecords=1)`

To limit the test data to items that are checked out, use `status.name=="Checked out"` as the `itemQuery`.
