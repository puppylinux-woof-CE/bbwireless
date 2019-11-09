# bbwireless
A script to connect to wireless networks

**bbwireless** is designed to be as minimal as possible.
It uses `/bin/ash` as the shell and mostly uses `busybox` utilities making it ideal for embedded systems.
It is completely command line based so will run in a virtual terminal or console.
A series of yes/no questions are asked, the network is scanned and the option is given to join a network.
The aim is to be visually appealing with colour dialogs.
At this stage it does not support enterprise networks.

## Depends
* busybox
* wpa_supplicant
* dhcpcd
* wireless-tools
* dialog
* gettext
#### optional
* nano
* mp
* leafpad
* geany
* medit
### busybox builtins
#### required
* ash
* echo
* route
* cat
* ls
* head
* tail
* rev
* cut
* cp
#### optional
* vi

## Screenshot
![bbwireless in virtual terminal](http://01micko.com/images/bbwireless.png)

## Hacking
Please no external calls to cut, awk, sed, grep. Only use the functions in the script that refer to busybox builtins. If you need to call a new busybox applet then create a simple funtion similar to below:
```shell
#------------------------busybox commands-------------------------------
_echo() {
	busybox echo "$@"
}
_route() {
	busybox route "$@"
}
_cat() {
	busybox cat "$@"
}

```
Most stream editing is done with `while|read` loops. All pull requests will be considered. Try and keep code neat with informative, yet minimal comments and mostly within the 80 char limit. The coding style is fairly conventional. All indentations are tabs except where it may go over the 80 char limit by 1 or 2 spaces otherwise split the line with escape, `\`. The exception is gettexted strings. Make sure you create a new POT file (translations) if you edit a string or create a new one.

## Translations
There is a pot file created with `xgettext` at `usr/share/doc/nls/bbwireles.sh/`
Please create po files for your language of choice and issue a pull request or post it somewhere with a link. You will be credited for your work.

## Features
* connect to secured wpa networks, open networks and hidden essids
* configure multiple networks
* change the priority of networks
* create a script in `/etc/init.d` to start the wireless services at boot
* start stop and restart the wireless and dhcpcd services

## Bugs
There will certainly be one or two. Then one or two more, and so on. Fix them and issue a pull request!

### TO DO
* support enterprise networks
* make 'puppyisms' optional
