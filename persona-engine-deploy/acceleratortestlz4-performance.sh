#!/bin/sh
#
# accelerator-performance - run accelerator performance script
#
# Copyright: Skyhook Wireless, 2016

# Extract relative location of accelerator scripts
script="`readlink --canonicalize $0`"
scriptdir="`dirname $script`"
basename="`basename $script`"

cd $scriptdir || exit 1
 
# Clean up the data from the previous test
# hadoop fs -rm -f -r /user/personas/data/acceleratortestlz4/userlocationlog/*
# hadoop fs -rm -f -r /user/personas/data/acceleratortestlz4/bind/user_campaigns
# hadoop fs -rm -f -r /user/personas/data/acceleratortestlz4/bind/vbind/*
# hadoop fs -rm -f -r /user/personas/data/acceleratortestlz4/bind/cbind/*
# hadoop fs -rm -f -r /user/personas/data/acceleratortestlz4/bind/_SUCCESS
# hadoop fs -rm -f -r /user/personas/data/acceleratortestlz4/logs/backup/*
aws s3 rm s3://personas-dev/customer/admarveltestlz4/bind/cbind/ --recursive --exclude '*' --include '*.lz4' --include '*SUCCESS' --include '*.bz2'
aws s3 rm s3://personas-dev/customer/admarveltestlz4/bind/vbind/ --recursive --exclude '*' --include '*.lz4' --include '*SUCCESS' --include '*.bz2'
aws s3 rm s3://personas-dev/customer/admarveltestlz4/userlocationlog/ --recursive --exclude '*' --include '*.lz4' --include '*SUCCESS' --include '*.bz2'
 
# Truncate the database tables
hive -e "use acceleratortestlz4; truncate table location_quarantine;"
hive -e "use acceleratortestlz4; truncate table personas_version;"
hive -e "use acceleratortestlz4; truncate table user_behaviors_internal;"
hive -e "use acceleratortestlz4; truncate table user_home_census;"
hive -e "use acceleratortestlz4; truncate table user_location_log;"

# Set the start and end dates.
STARTDATE="20140131"
ENDDATE="20140301"

if [ -e acceleratortestlz4-performance`date +'%Y%m%d'` ]; then
    echo $basename - Error: acceleratortestlz4-performance`date +'%Y%m%d'` exists, performance has been run today, exiting
    exit 1
else
    echo $basename - PARSE/BIND START DATE `date`
    nohup ./workflow/persona-runner.py --cfg-file ./workflow/acceleratortestlz4-runner.automation.cfg --start-date $STARTDATE --end-date $ENDDATE --log-level=DEBUG > acceleratortestlz4-performance.out.`date +'%Y%m%d'` 2>&1
    echo $basename - PARSE/BIND END DATE `date`
fi

cd homing

for i in 2014-03-01 
do

	echo $basename - $i
    	echo $basename - HOME/PERSONIFY START DATE `date`
	# nohup ./home_personify_acceleratortestlz4 -d $i -c acceleratortestlz4 -s /var/lib/hadoop-hdfs/deploy/persona-engine-qa > home_personify_acceleratortestlz4$i.out 2>&1
	nohup ./home_personify.py --cfg-file=accelerator_personify.properties --bind-date=$i > acceleratortestlz4.$i.log &
    	echo $basename - HOME/PERSONIFY END DATE `date`
	hive -e "use acceleratortestlz4; select behavior_id, COUNT(behavior_id) mycount from user_behaviors group by behavior_id order by behavior_id;" > home_personify_acceleratortestlz4.$i.csv
	diff home_personify_acceleratortestlz4.$i.csv baseline/home_personify_acceleratortestlz4.$i.csv > home_personify_acceleratortestlz4.$i.csv.diff
 
	if [ ! -s home_personify_acceleratortestlz4.$i.csv.diff ]; then 
		MAIL_TITLE='HOME PERSONIFY '$i' PASSED\\!'
		echo $basename - $MAIL_TITLE | cat home_personify_acceleratortestlz4.$i.out | mail -s $MAIL_TITLE personas@skyhookwireless.com
		# rm home_personify_acceleratortestlz4.$i.csv.diff home_personify_acceleratortestlz4.$i.csv home_personify_acceleratortestlz4.$i.out;
	else 
		MAIL_TITLE='HOME PERSONIFY '$i' FAILED\\!'
		echo $basename - $MAIL_TITLE | cat home_personify_acceleratortestlz4.$i.csv.diff home_personify_acceleratortestlz4.$i.out | mail -s $MAIL_TITLE personas@skyhookwireless.com
		# exit 1;
	fi

cd ..

done