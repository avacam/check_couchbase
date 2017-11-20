#!/bin/bash
# Author:   Cameron Pierce
# Purpose:  Monitor Couchbase Server resource use and Cluster state
# Modified: 2017-11-16
# Version:  1.2
# Changelog:
#   2014-09-03 CMP: initial release 
#   2017-11-16 CMP: Revised logic, added monitoring of HDD cache, and removed dependency on a temp file
#
# Requirements: bc bash couchbase-cli
################################################################################

# VARIABLES
intReturnCode=0 # Codes: 0 - Pass, 1 - Warning, 2 - Critical, 3 - Unknown
strCliServerInfo="" # variable for storing returned information from couchbase-cli server-info command
strServer=$HOSTNAME
strUsername="Administrator"
strPassword="**********"
decPercentRam=0
decPercentHdd=0
decCriticalPercentRam=90
decWarningPercentRam=75
decCriticalPercentHdd=90
decWarningPercentHdd=75

# FUNCTIONS
function exit_call {
	# ARG1 = Check MK status code
	# ARG2 = Descriptive text for status
	intReturnCode=$1
	strCodeDescription="$2"
	case $intReturnCode in
		1)
		strStatus="WARNING" ;;
		2)
		strStatus="CRIT" ;;
		3)
		strStatus="UNKNOWN" ;;
		*)
		strStatus="OK" ;;
	esac
	echo "$intReturnCode Couchbase_Status RAM=$decPercentRam;$decWarningPercentRam;$decCriticalPercentRam;0;100|HDD=$decPercentHdd;$decWarningPercentHdd;$decCriticalPercentHdd;0;100 $strStatus - $strCodeDescription"
	exit
}
# MAIN

# gather couchbase status information
if [ -f /opt/couchbase/bin/couchbase-cli ]; then
	#echo "" > $fileTemp
	strCliServerInfo=$(/opt/couchbase/bin/couchbase-cli server-info -c $strServer -u $strUsername -p "$strPassword")
else
	# binary missing
	exit_call 3 "Couchbase CLI binary missing"
fi


# verify that the server is healthy
echo "$strCliServerInfo" | grep -q '"status": "healthy",'
RETVAL=$?
if [ $RETVAL != 0 ]; then
	exit_call 2 "Cache not healthy"
fi

# verify that the cluster is healthy and active (each server in the cluster should be listed as healthy)
echo "$strCliServerInfo" | grep -q '"clusterMembership": "active",'
if [ $RETVAL != 0 ]; then
	exit_call 2 "node not active in couchbase cluster"
fi
# RAM Utilization
# remove linefeeds
#perl -i -p -e 's/\n//' $fileTemp

#strTitle=ram
# only use the RAM section from output
ram=$(echo $strCliServerInfo | sed -e "s/.*\"ram\": {\([^}]*\).*/\1/" |sed -e 's/[[:blank:]]\{1,\}/ /g')
hdd=$(echo $strCliServerInfo | sed -e "s/.*\"hdd\": {\([^}]*\).*/\1/" |sed -e 's/[[:blank:]]\{1,\}/ /g')
#DEBUG echo $ram
# example output: "quotaTotal": 3317694464.0, "total": 4147204096.0, "used": 3866730496.0, "usedByData": 118652502
# get ramTotal from output
ramTotal=$(echo $ram|sed -e "s/.*\"total\": \([[:digit:]]\{1,\}\).*/\1/")
hddTotal=$(echo $hdd|sed -e "s/.*\"total\": \([[:digit:]]\{1,\}\).*/\1/")
#DEBUG echo RAM Total: $ramTotal
# get ramUsed from output
ramUsed=$(echo $ram|sed -e "s/.*\"usedByData\": \([[:digit:]]\{1,\}\).*/\1/")
hddUsed=$(echo $hdd|sed -e "s/.*\"usedByData\": \([[:digit:]]\{1,\}\).*/\1/")
#DEBUG echo RAM Used: $ramUsed

decPercentRam=$(echo "scale=2; $ramUsed/$ramTotal*100" | bc -l )
decPercentRam=$( echo $decPercentRam / 1 | bc)
decPercentHdd=$(echo "scale=2; $hddUsed/$hddTotal*100" | bc -l )
decPercentHdd=$( echo $decPercentHdd / 1 | bc)
#DEBUG echo Percent: $decPercent
# test whether percent exceeds Warning and Critical thresholds
if [ $decPercentRam -ge $decCriticalPercentRam ]; then
	intReturnCode=2
	strCodeDescription="RAM use of $decPercentRam% exceeds $decCriticalPercentRam%"
elif [ $decPercentRam -ge $decWarningPercentRam ]; then
	intReturnCode=1
	strCodeDescription="RAM use of $decPercentRam% exceeds $decWarningPercentRam%"
else
	strCodeDescription="RAM use is $decPercentRam%"
fi
if [ $decPercentHdd -ge $decCriticalPercentHdd ]; then
	intReturnCode=2
	strCodeDescription="HDD use of $decPercentHdd% exceeds $decCriticalPercentHdd% and $strCodeDescription"
elif [ $decPercentHdd -ge $decWarningPercentHdd ]; then
	intReturnCode=1
	strCodeDescription="HDD use of $decPercentHdd% exceeds $decWarningPercentHdd% and $strCodeDescription"
else
	strCodeDescription="HDD use is $decPercentHdd% and $strCodeDescription"
fi
exit_call $intReturnCode "$strCodeDescription"
