#!/bin/bash

cd $(dirname ${BASH_SOURCE[0]})
echo $$ > file-pipes/set-day-night-pid.txt

if ! test -f file-pipes/location.txt
then
	echo 'ERROR: No location provided (file-pipes/location.txt)'
	touch file-pipes/location.txt
	inotifywait -e close_write file-pipes/location.txt
fi

sunwait poll `cat file-pipes/location.txt` > file-pipes/day-night.txt

while true
do
	#sunwait wait `cat file-pipes/location.txt`
	sleep 1m
	sunwait poll `cat file-pipes/location.txt` > file-pipes/day-night.txt
done

