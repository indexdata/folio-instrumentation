# Check in test data

The following data files in this directory are needed to support the Jmeter script during its execution:

- `credentials.csv`: a file to specify connection information and credentials for the tenant being tested. Format: `[Okapi hostname],[Okapi protocol],[Okapi port],[FOLIO username],[FOLIO password],[tenant ID]`. Default for protocol is http, default port is 80 (443 for https).
- `item_barcodes.csv`: a list of item barcodes to check in.
- `service_point.csv`: a list of one or more service points to use for check out.

See the main [README](../README.md#preparing-the-test-data) for this test for directions to prepare the test data.
