# JMeter performance test for discovery system behavior

This test (`mockDiscovery_randomized.jmx`) exercises a FOLIO backend system by performing the API calls used by VuFind to retrieve instance, holdings, and item data.

## Test notes

* The test emulates a VuFind system user logging in to the FOLIO system, then building result set pages based on a configurable number of instances per result set page until the test time expires.
* The test is targeted at a Honeysuckle FOLIO environment.

## Test data

The following data files in the needed to support the JMeter script during its execution. 

- `config_random.csv`: a file to specify connection information and credentials for the tenant being tested. Format: `[tenant ID],[FOLIO username],[FOLIO password],[Okapi protocol],[Okapi hostname],[Okapi port]`. Default for protocol is http, default port is 80 (443 for https).
- `instances.csv`: a list of instance HRIDs to build result set pages.

Test data can be generated using the [test data script](#preparing-the-test-data), see below.

## User properties

The test can be configured using the following user properties (set in a properties file or with the `--jmeterproperty | -J` command line option). They can also be configured using the "User Defined Variables" component in the JMeter console:

- `VUSERS`: the number of users to emulate, default 1
- `RAMP_UP`: the ramp-up period in seconds, default 1
- `DURATION`: how long to run the test in seconds, default 300
- `RESULTSET_SIZE`: number of instances in a result set, default 15

## Preparing the test data

You can prepare a set of test data from a FOLIO environment using the [scripts/generate-test-data.pl](scripts/generate-test-data.pl) script. The script will generate all the required test data files in the output directory. Any files with those names in the output directory will be overwritten.

Note that the HRID parsing routine is not perfect and will not necessarily pick up all HRIDs, depending on how the server chunks the HTTP response.

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
  "instanceQuery": "[CQL query to retrieve instances, optional]",
  "instanceCount": 100000
}
```

The `okapi`, `tenant`, `user`, and `password` properties are required. The other properties are optional. Any CQL queries are ANDed to the default queries (see below). The defaults for other optional properties are as shown above.

Default instanceQuery: `(cql.allRecords=1)`
