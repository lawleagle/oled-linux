#!/bin/bash

##
# Backlight driver file location
backlight_dir="/sys/class/backlight/intel_backlight/"

##
# OLED Display Name
# If not set the script will attempt to guess it.
# Use `xrandr --current | grep " connected"` to get a list of all connected
# displays. Examples are: e-DP1, eDP-1, eDP-1-1
oled_screen=""

##
# Brightness step size
# How quickly to change the screen brightness?
# Values between 1(immediately) to 500(it takes about 10 seconds for the whole range) make sense.
# Default is 10.
brightness_step_size_factor=10

##
# Redshift (Night Light) functionality
# If enabled the script will also change the color temperature of the display.
use_redshift=true

##
# Color temperature during the day
daylight_temperature=6500

##
# Color temperature at night
night_temperature=3500

##
# Color temperature step
# how much to change the temperature of the night light on one frarme
# the lower the value, the longer it takes to transition to a new redshift temperature
# has to be an integer value, no fractional values are allowed
redshift_step_size=50

##
# Location
# The script will use geoclue to automatically get your location. If you would
# like to provide it manually instead use the following format:
# location="42.6604944N 24.7494263E"
location=""

# ------------------------------------------------------------------------------

cd $(dirname ${BASH_SOURCE[0]})

function color(){ echo -e "\e[$1m${*:2}\e[0m"; }
function red(){ color 31 $@; }
function yellow(){ color 33 $@; }
function blue(){ color 34 $@; }
function abort(){ red $@; exit 1; }

# If no oled_screen is set - attempt to guess it
if [[ -z $oled_screen ]]; then
    oled_screen=$(xrandr --current | grep -m 1 " connected" | awk '{print $1}')
    blue "Guessed OLED display as: $oled_screen"
fi

# Verify the backlight directory is set correctly
if ! test -d "$backlight_dir"; then
    abort "ERROR: wrong configuration. Backlight directory does not exist."
fi

# Verify dependencies are installed
if ! command -v inotifywait; then
    abort "ERROR: dependency 'inotifywait' is not installed."
fi

if $use_redshift; then
    if ! command -v redshift; then
        yellow "WARNING: optional dependency 'redshift' is not installed." \
               "Redshift functionality disabled."
        use_redshift=false
    fi
    if ! command -v sunwait; then
        yellow "WARNING: optional dependency 'sunwait' is not installed." \
               "Redshift functionality disabled."
    fi

    # Attempt to get the location of where-am-i from geoclue2 demos
    if [[ -z $location ]]; then
        where_am_i=NULL
        for where_am_i_location in "/usr/lib/geoclue-2.0/demos/where-am-i" \
                                   "/usr/libexec/geoclue-2.0/demos/where-am-i"; do
            if test -f $where_am_i_location; then
                where_am_i=$where_am_i_location
                break
            fi
        done
        if ! test -f $where_am_i; then
            yellow "WARNING: Optional dependency 'where-am-i' from geoclue2 demo files could not found." \
                   "Please install geoclue2 and or geoclue2-demo." \
                   "Redshift functionality disabled."
            use_redshift=false
        fi
    fi
fi

max_brightness=$(cat "$backlight_dir/max_brightness")

target_brightness=$(cat "$backlight_dir/brightness")
current_brightness=$max_brightness

target_shift=$daylight_temperature
current_shift=$daylight_temperature

if ! test -d .file-pipes; then
  mkdir .file-pipes
fi

##
# Redshift background services
#
if $use_redshift; then
    if [[ -z $location ]]; then
        blue "Enabled location service."
        ##
        # Location service
        #
        {
            sleep 1s # Just to make sure the other services are running
            while true
            do
              $where_am_i > .file-pipes/where-am-i-result.txt

              latitude=$(cat .file-pipes/where-am-i-result.txt | grep -m 1 Latitude | awk '{FS=":";print $2}' | sed 's/?//g')
              longitude=$(cat .file-pipes/where-am-i-result.txt | grep -m 1 Longitude | awk '{FS=":";print $2}'| sed 's/?//g')
              latitude=${latitude::-1} # removes trailing °
              longitude=${longitude::-1} # removes trailing °

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

                echo "${latitude}${latitude_suffix} ${longitude}${longitude_suffix}" > .file-pipes/current-location.txt

                sleep 30m
            done
        } &

        ##
        # Watch location service
        #
        {
            if ! test -f .file-pipes/current_location.txt; then
                touch .file-pipes/current-location.txt
            fi

            while true; do
                inotifywait -e close_write .file-pipes/current-location.txt
                if ! diff .file-pipes/location.txt .file-pipes/current-location.txt
                then
                    cp .file-pipes/current-location.txt .file-pipes/location.txt
                fi
            done
        } &
    else
      echo $location > .file-pipes/location.txt
    fi

    ##
    # Set day night service
    #
    {
        # Make sure the location.txt exists before calling sunwait
        if ! test -f .file-pipes/location.txt; then
            touch .file-pipes/location.txt
            inotifywait -e close_write .file-pipes/location.txt
        fi

        while true
        do
          sunwait poll `cat .file-pipes/location.txt` > .file-pipes/day-night.txt
          sleep 1m
        done
    } &
fi

while true;
do
    target_brightness=$(cat "$backlight_dir/brightness")


    if test -f .file-pipes/day-night.txt; then
      day_night=$(cat .file-pipes/day-night.txt)
    else
      touch .file-pipes/day-night.txt
      day_night="DAY"
    fi

    if $use_redshift && [ "$day_night" = "NIGHT" ]
    then
        target_shift=$night_temperature
    else
        target_shift=$daylight_temperature
    fi

    if [ $current_brightness -eq $target_brightness ] && [ $current_shift -eq $target_shift ]
    then
        inotifywait -e close_write $backlight_dir/brightness -e close_write "./.file-pipes/day-night.txt" > /dev/null
        continue
    fi

    step=$((current_brightness - target_brightness))
    if [ $step -lt 0 ]; then step=$((-step)); fi
    brightness_step_size=$((step / brightness_step_size_factor))
    if [ $brightness_step_size -lt $((max_brightness / 500)) ]; then brightness_step_size=$((max_brightness / 500)); fi
    if [ $step -gt $brightness_step_size ]; then step=$brightness_step_size; fi

    if [ $current_brightness -gt $target_brightness ]
    then
        current_brightness=$((current_brightness - step))
    else
        current_brightness=$((current_brightness + step))
    fi

    percent=`echo "$current_brightness / $max_brightness * 0.9 + 0.1" | bc -l`

    if $use_redshift; then
        step=$((current_shift - target_shift))
        if [ $step -lt 0 ]; then step=$((-step)); fi
        if [ $step -gt $redshift_step_size ]; then step=$redshift_step_size; fi

        if [ $current_shift -gt $target_shift ]
        then
            current_shift=$((current_shift - step))
        else
            current_shift=$((current_shift + step))
        fi

        redshift -m randr:screen=$oled_screen -P -O $current_shift -b $percent
        xrandr | grep -m 1 " connected " | awk '{print $1}' | while read -r line
        do
            if ! [ "$line" == "$oled_screen" ]
            then
                redshift -m randr:screen=$line -P -O $current_shift
            fi
        done
    else
        xrandr --output $oled_screen --brightness $percent
    fi
done
