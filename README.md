# check_couchbase
BASH script for monitoring the health of a couchbase node and its state in a cluster.

Sample output:
 /usr/lib/check_mk_agent/local/check_couchbase.bash
 0 Couchbase_Status RAM=3;75;90;0;100|HDD=18;75;90;0;100 OK - HDD use is 18% and RAM use is 3%

Aerting thresholds for RAM and HDD use can be set within the script.
