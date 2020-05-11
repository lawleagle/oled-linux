#!/bin/bash
cd "$(dirname ${BASH_SOURCE[0]})"

if ! test -f file-pipes/current_location.txt
then
	touch file-pipes/current-location.txt
	inotifywait -e close_write file-pipes/current-location.txt
fi

while true
do
	if ! diff file-pipes/location.txt file-pipes/current-location.txt
	then
		cp file-pipes/current-location.txt file-pipes/location.txt
		kill -9 `cat file-pipes/set-day-night-pid.txt`
	fi
	
	inotifywait -e close_write file-pipes/current-location.txt
done

