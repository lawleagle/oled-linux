#!/bin/bash
cd "$(dirname ${BASH_SOURCE[0]})"


backlight_dir="/sys/class/backlight/intel_backlight/"
test -d "$backlight_dir" || exit 0

max_brightness=$(cat "$backlight_dir/max_brightness")	


target_brightness=$(cat "$backlight_dir/brightness")
current_brightness=$(cat "$backlight_dir/max_brightness")

target_shift=6500
current_shift=6500

while true;
do
	target_brightness=$(cat "$backlight_dir/brightness")

	day_night=$(cat "./day-night.txt")
	if [ "$day_night" = "NIGHT" ]
	then
		target_shift=3500
	else
		target_shift=6500
	fi

	if [ $current_brightness -eq $target_brightness ] && [ $current_shift -eq $target_shift ]
	then
		inotifywait -e close_write $backlight_dir/brightness -e close_write './day-night.txt' > /dev/null
		continue
	fi

	step=$((current_brightness - target_brightness))
	if [ $step -lt 0 ]; then step=$((-step)); fi
	if [ $step -gt 12 ]; then step=12; fi

	if [ $current_brightness -gt $target_brightness ]
	then
		current_brightness=$((current_brightness - step))
	else
		current_brightness=$((current_brightness + step))
	fi

	percent=`echo "$current_brightness / $max_brightness" | bc -l`

	step=$((current_shift - target_shift))
	if [ $step -lt 0 ]; then step=$((-step)); fi
	if [ $step -gt 50 ]; then step=50; fi

	if [ $current_shift -gt $target_shift ]
	then
		current_shift=$((current_shift - step))
	else
		current_shift=$((current_shift + step))
	fi

	echo $current_brightness $target_brightness
	echo $current_shift $target_shift
	#echo "xrandr --output eDP-1 --brightness $percent" > /tmp/oled-brightness.log
	#xrandr --output eDP-1 --brightness $percent
	#echo "redshift -P -O $current_shift -b $percent"
	redshift -P -O $current_shift -b $percent
done

