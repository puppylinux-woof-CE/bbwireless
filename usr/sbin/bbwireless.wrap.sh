#!/bin/ash

# bbwireless.sh wrapper

if [ $DISPLAY ];then
	xterm -hold -e bbwireless.sh
else
	bbwireless.sh
fi
