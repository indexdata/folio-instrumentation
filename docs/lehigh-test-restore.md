# How to restore lehigh-test.dev-us-east-2.indexdata.com

After running performance tests that change the system, the database may need to be restored.

The pg\_dump file is on folio-bastion.folio-dev.indexdata.com at `/data/pg_dump/lehigh-perf-test-20210405.dmp`. To restore:

1. Scale down flux in the cluster: `kubectl -n flux scale deployment flux --replicas=0`
1. Shut down Okapi: `kubectl -n lehigh-test scale statefulset okapi --replicas=0`
1. Shut down all backend modules: `kubectl -n lehigh-test scale deployment -l folio_role=backend-module --replicas=0`
1. Restore the tenant schemas (from bastion host): `pg_restore -U folio -h dev-folio-eks-2-lehigh-test.ccm8pnckccib.us-east-2.rds.amazonaws.com -d lehigh_test --clean --if-exists --single-transaction --verbose lehigh-perf-test-20210405.dmp`
1. Execute `VACUUM ANALYZE` on the database (from bastion host): `psql -U postgres -h dev-folio-eks-2-lehigh-test.ccm8pnckccib.us-east-2.rds.amazonaws.com -c 'VACUUM ANALYZE' lehigh_test` (no need to wait for this step to complete before moving to the next)
1. Scale flux back up in the cluster: `kubectl -n flux scale deployment flux --replicas=1`. This will restart all the modules and Okapi.

This restore process takes about 2 hours.

Database passwords are stored in AWS Secrets Manager.
