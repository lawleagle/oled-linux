#!/bin/bash
cd "$(dirname ${BASH_SOURCE[0]})"


#location of where-am-i from geoclue2 demos
where_am_i='/usr/lib/geoclue-2.0/demos/where-am-i'



if ! test -f $where_am_i
then
	echo "ERROR: Dependency 'where-am-i' from geoclue2 demo files is not located properly. Please install geoclue2 or update file location in this script"
	kill -9 $PPID
	exit 0
fi


while true
do
	$where_am_i > file-pipes/where-am-i-result.txt

	latitude=`cat file-pipes/where-am-i-result.txt | grep -m 1 Latitude | awk '{FS=":";print $2}' | sed 's/?//g'`
	longitude=`cat file-pipes/where-am-i-result.txt | grep -m 1 Longitude | awk '{FS=":";print $2}' | sed 's/?//g'`

	if (( $(echo "$latitude < 0" | bc -l) ))
	then
		latitude_suffix='S'
	else
		latitude_suffix='N'
	fi

	if (( $(echo "$longitude < 0" | bc -l) ))
	then
		longitude_suffix='W'
	else
		longitude_suffix='E'
	fi

	echo "${latitude}${latitude_suffix} ${longitude}${longitude_suffix}" > file-pipes/current-location.txt

	exit 0
	sleep 10m
done

