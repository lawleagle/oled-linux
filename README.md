# OLED Linux
`oled-linux.sh` will watch the backlight changes in `/sys/class/backlight/intel_backlight` and apply changes over there to OLED screens

## Features
- Brightness Change on OLED screens on Linux (main point of the repository)
- Smooth Brightness Control (changes in brightness will be applied gradually instead of just jumping to the new brightness)
- Night Light Support (with or without geolocation and with smooth cycle changes)
- Multiple Displays Support
- Works directly on X, is not tightly coupled to any desktop environment, so it should work well in almost any circumstance

## Dependencies
- `inotifywait` - used for watching for file changes with as little CPU usage as possible
- `sunwait` - (optional) used for monitoring day/night cycle for night light feature
- `geoclue2` - (optional) used for getting current location for day/night cycle for night light feature. Optional because location can be set manually

## Installation (Ubuntu)

```bash
sudo apt install inotify-tools

# For redshift (Night Light) support, also add
sudo apt install geoclue2.0 geoclue-2-demo
snap install sunwait
```

Clone the repository and test the script by running it. To automatically run it
at startup you should add it to your [startup applications](https://help.ubuntu.com/stable/ubuntu-help/startup-applications.html.en).


## Night Light
If night light is enabled in `oled-linux.sh`, all brightness changes are applied using `redshift`, which allows for Night Light support.
If Night Light is disabled in the config, brightness changes will be applied with `xrandr`.

Default values for night filter:  
`DAY = 6500` (default, unchanged display)
`NIGHT = 3500` (default night-filter value)

You can change the night filter value to whatever you want by modifying
`oled-linux.sh` (see the configuration options below). You can also adjust
the daylight value so that you can add a filter during the day as well.

Night Light can work without geolocation, in which case you have to specify your
location in the configuration section using the following format:
`LATITUDE_DEGREES[N/S] LONGITUDE_DEGREES[E/W]`.

## Configuration
Configuration can be set in the `oled-linux.conf` file.
```bash
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
# Can be configured at runtime.
brightness_step_size_factor=10

##
# Redshift (Night Light) functionality
# If enabled the script will also change the color temperature of the display.
# Can be configured at runtime.
use_redshift=true

##
# Color temperature during the day
# Can be configured at runtime.
daylight_temperature=6500

##
# Color temperature at night
# Can be configured at runtime.
night_temperature=4800

##
# Color temperature step
# how much to change the temperature of the night light on one frame
# the lower the value, the longer it takes to transition to a new redshift temperature
# has to be an integer value, no fractional values are allowed
# Can be configured at runtime.
redshift_step_size=50

##
# Location
# The script will use geoclue to automatically get your location. If you would
# like to provide it manually instead use the following format:
# location="42.6604944N 24.7494263E"
location=""
```

## Performance

`oled-linux.sh` uses `inotifywait` to watch for changes in:
```
file-pipes/day-night.txt
/sys/class/backlight/intel_backlight
```

and it will only run when there are changes to apply.

Internally the script uses three services:

1. The first checks for location information using geoclue2 every 30 minutes and writes that info to `file-pipes/current-location.sh`.
2. The second watches for changes in `file-pipes/current-location.sh` and if the location changed, writes the new location to `file-pipes/location.txt`.
3. The third writes `DAY` or `NIGHT` to `file-pipes/current-location.sh` whenever it becomes day/night outside according to location data and when the location data is changed. Whenever these things are not happening, this script will sleep.

## Troubleshooting

If you are running with geolocation enabled, it might take a few minutes for location data to become available. In most cases, location data is only available on active internet connection.

`oled-linux` may controlling the wrong display. If so, manually set the `oled_screen` value to the correct value (check the configuration section).

## Contribute

If you found bugs, report them on the issues page. If you modified something, make a pull request.

## Community

There is a channel for this project on this server. If more will be required, more will be provided.
Discord: https://discord.gg/t4nV3gpJbU
