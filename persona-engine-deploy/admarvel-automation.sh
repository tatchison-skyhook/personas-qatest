#!/bin/sh
#
# admarvel-automation.sh - run admarvel automation script
#
# Copyright: Skyhook Wireless, 2016

# Extract relative location of admarvel scripts
script="`readlink --canonicalize $0`"
scriptdir="`dirname $script`"

cd $scriptdir || exit 1
 
# Clean up the data from the previous test
# hadoop fs -rm -f -r /user/personas/data/admarveltest/userlocationlog/*
# hadoop fs -rm -f -r /user/personas/data/admarveltest/bind/user_campaigns
# hadoop fs -rm -f -r /user/personas/data/admarveltest/bind/vbind/*
# hadoop fs -rm -f -r /user/personas/data/admarveltest/bind/cbind/*
# hadoop fs -rm -f -r /user/personas/data/admarveltest/bind/_SUCCESS
# hadoop fs -rm -f -r /user/personas/data/admarveltest/logs/backup/*
aws s3 rm s3://personas-dev/customer/admarveltest/bind/cbind/ --recursive --exclude '*' --include '*.bz2' --include '*SUCCESS'
aws s3 rm s3://personas-dev/customer/admarveltest/bind/vbind/ --recursive --exclude '*' --include '*.bz2' --include '*SUCCESS'
aws s3 rm s3://personas-dev/customer/admarveltest/userlocationlog/ --recursive --exclude '*' --include '*.bz2' --include '*SUCCESS'
 
# Truncate the database tables
hive -e "use admarveltest; truncate table location_quarantine;"
hive -e "use admarveltest; truncate table personas_version;"
hive -e "use admarveltest; truncate table user_behaviors_internal;"
hive -e "use admarveltest; truncate table user_home_census;"
# hive -e "use admarveltest; truncate table user_location_log;"

# Set the start and end dates.
STARTDATE="20150721"
ENDDATE="20151231"

if [ -e admarveltest-automation.out.`date +'%Y%m%d'` ]; then
    echo Error: admarveltest-automation.out.`date +'%Y%m%d'` exists, automation has been run today, exiting
    exit 1
else
    echo PARSE/BIND START DATE `date`
    nohup python ./workflow/persona-runner.py --cfg-file ./workflow/admarveltest-runner.automation.cfg --start-date $STARTDATE --end-date $ENDDATE --log-level=DEBUG > admarveltest-automation.out.`date +'%Y%m%d'` 2>&1
    echo PARSE/BIND END DATE `date`
fi

cd homing

for i in 2015-12-30 2015-11-30 2015-10-30 2015-09-30 2015-08-30 2015-07-30
do

	echo $i
    	echo HOME/PERSONIFY START DATE FOR $i `date`
	nohup python ./home_personify.py --cfg-file=admarveltest_personify.automation.properties --bind-date=$i > admarveltest_personification_$i.out 2>&1
	hive -e "use admarveltest; select behavior_id, COUNT(behavior_id) mycount from user_behaviors_internal group by behavior_id order by behavior_id;" > home_personify_admarveltest.$i.csv
    	echo HOME/PERSONIFY END DATE FOR $i `date`
	diff home_personify_admarveltest.$i.csv ../baseline/home_personify_admarveltest.$i.csv > home_personify_admarveltest.$i.csv.diff
 
	if [ ! -s home_personify_admarveltest.$i.csv.diff ]; then 
		MAIL_TITLE='HOME PERSONIFY '$i' PASSED!'
		echo $MAIL_TITLE | cat admarveltest_personification_$i.out | mail -s "$MAIL_TITLE" tatchison@skyhookwireless.com
		# rm home_personify_admarveltest.$i.csv.diff home_personify_admarveltest.$i.csv admarveltest_personification_$i.out;
	else 
		MAIL_TITLE='HOME PERSONIFY '$i' FAILED!'
		echo $MAIL_TITLE | cat home_personify_admarveltest.$i.csv.diff admarveltest_personification_$i.out | mail -s "$MAIL_TITLE" tatchison@skyhookwireless.com
		# exit 1;
	fi
done

cd ..

