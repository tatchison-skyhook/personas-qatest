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
# hadoop fs -rm -f -r /user/personas/data/acceleratortest/userlocationlog/*
# hadoop fs -rm -f -r /user/personas/data/acceleratortest/bind/user_campaigns
# hadoop fs -rm -f -r /user/personas/data/acceleratortest/bind/vbind/*
# hadoop fs -rm -f -r /user/personas/data/acceleratortest/bind/cbind/*
# hadoop fs -rm -f -r /user/personas/data/acceleratortest/bind/_SUCCESS
# hadoop fs -rm -f -r /user/personas/data/acceleratortest/logs/backup/*
aws s3 rm s3://personas-dev/customer/acceleratortest/bind/cbind/ --recursive --exclude '*' --include '*.lz4' --include '*SUCCESS' --include '*.bz2'
aws s3 rm s3://personas-dev/customer/acceleratortest/bind/vbind/ --recursive --exclude '*' --include '*.lz4' --include '*SUCCESS' --include '*.bz2'
aws s3 rm s3://personas-dev/customer/acceleratortest/userlocationlog/ --recursive --exclude '*' --include '*.lz4' --include '*SUCCESS' --include '*.bz2'
 
# Truncate the database tables
hive -e "use acceleratortest; truncate table location_quarantine;"
hive -e "use acceleratortest; truncate table personas_version;"
hive -e "use acceleratortest; truncate table user_behaviors_internal;"
hive -e "use acceleratortest; truncate table user_home_census;"
# hive -e "use acceleratortest; truncate table user_location_log;"

# Set the start and end dates.
STARTDATE="20140131"
ENDDATE="20140208"

if [ -e acceleratortest-performance`date +'%Y%m%d'` ]; then
    echo $basename - Error: acceleratortest-performance`date +'%Y%m%d'` exists, performance has been run today, exiting
    exit 1
else
    echo $basename - PARSE/BIND START DATE `date`
    nohup python ./workflow/persona-runner.py --cfg-file ./workflow/acceleratortest-runner.automation.cfg --start-date $STARTDATE --end-date $ENDDATE --log-level=DEBUG > acceleratortest-performance.out.`date +'%Y%m%d'` 2>&1
    echo $basename - PARSE/BIND END DATE `date`
fi

cd homing

for i in 2014-02-08 
do

	echo $basename - $i
    	echo $basename - HOME/PERSONIFY START DATE `date`
	nohup python ./home_personify.py --cfg-file=accelerator_personify.properties --bind-date=$i > acceleratortest_personification_$i.log 2>&1
    	echo $basename - HOME/PERSONIFY END DATE `date`
	hive -e "use acceleratortest; select behavior_id, COUNT(behavior_id) mycount from user_behaviors group by behavior_id order by behavior_id;" > home_personify_acceleratortest.$i.csv
	diff home_personify_acceleratortest.$i.csv ../baseline/home_personify_acceleratortest.$i.csv > home_personify_acceleratortest.$i.csv.diff
 
	if [ ! -s home_personify_acceleratortest.$i.csv.diff ]; then 
		MAIL_TITLE='ACCELERATOR AUTOMATION TEST HOME PERSONIFY '$i' PASSED!'
		echo $basename - $MAIL_TITLE | cat acceleratortest_personification_$i.log | mail -s "$MAIL_TITLE" personas@skyhookwireless.com
		# rm home_personify_acceleratortest.$i.csv.diff home_personify_acceleratortest.$i.csv home_personify_acceleratortest.$i.out;
	else 
		MAIL_TITLE='ACCELERATOR AUTOMATION TEST HOME PERSONIFY '$i' FAILED!'
		echo $basename - $MAIL_TITLE | cat home_personify_acceleratortest.$i.csv.diff acceleratortest_personification_$i.log | mail -s "$MAIL_TITLE" personas@skyhookwireless.com
		# exit 1;
	fi
done
cd ..
