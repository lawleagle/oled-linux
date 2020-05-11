#!/bin/bash
cd $(dirname ${BASH_SOURCE[0]})


sunwait poll `cat location.txt` > day-night.txt

while true
do
	sunwait wait `cat location.txt`
	sunwait poll `cat location.txt` > day-night.txt
done

