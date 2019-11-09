#!/bin/ash

# bbwireless
# (C) 01micko 2019, gplV2
# a cli based wireless network tool using wpa_supplicant
# using +busybox +wpa_supplicant +dialog +dhcpcd +wireless-tools +gettext
# busybox needs ash, echo, route, cat, ls, head, tail, rev, cut, cp
# at a minimum
# +nano, +mp, +busybox vi, +medit, +leafpad, +geany
# are optional external dependencies

ver=0.1
prog=${0##*/}
TMPDIR=/tmp/${prog}$$
mkdir -p ${TMPDIR}
CONFDIR=/etc/bbwireless

#----------------------------globals------------------------------------
export TEXTDOMAIN=${prog}
export OUTPUT_CHARSET=UTF-8
essid=''
keystate='' # open or encrypted
passkey=''
hidden=1    # 0 = hidden essid
prio=1      # network priority for multiple networks
iface=''

#-------------------------gettext strings-------------------------------
WELCOME=$(gettext "Welcome to the wireless network setup tool.")
END=$(gettext 'Finished!')
# usage
U0=$(gettext "Usage")
UL1_0=$(gettext "Just run")
UL1_1=$(gettext "from a virtual terminal or console.")
UL2=$(gettext "You will be asked a series of questions about your network.")
UL3=$(gettext "Answer them (y/n), press enter/return and you should be able to connect.")
UL4=$(gettext "show this help and exit.")
UL5=$(gettext "if multiple networks configured, manage the priority")
UL6=$(gettext "restart and re-connect to network")
UL7=$(gettext "disconnect from network")
UL8=$(gettext "create startup file for starting at boot")
UL9=$(gettext "list currently configured networks")
UL10=$(gettext "show version and exit.")
UL11=$(gettext "Advanced usage")
UL12=$(gettext "Run the program and enter your network name and pass key")
UL13=$(gettext "NOTE: this method doesn't work with hidden or unsecured networks.")
# CON
CL0=$(gettext "A network connection is established on")
CL1=$(gettext "There is no network connection.")
# Setup iface
SIL0=$(gettext "A network file already exists.")
SIL1=$(gettext "Only choose to reconstruct it if you have")
SIL2=$(gettext "plugged in a new wireless device.")
SIL3=$(gettext "Overwrite?")
SIL4=$(gettext "creating /etc/network/interfaces")
# Scan and Display
SCL0=$(gettext "Scanning")
SCL1=$(gettext "Sorry scanning failed, try again.")
SCL2=$(gettext "Please enter the number of the Network you wish to connect with.")
SCL3=$(gettext "is invalid, try again")
SCL4=$(gettext "OK, we will attempt to connect to $essid")
# hidden
HL0=$(gettext "Enter the hidden network name")
HL1_0=$(gettext "Using")
HL1_1=$(gettext "as the network to connect to")
# pass
PL0=$(gettext "Password")
PL1=$(gettext "Enter your password")
PL2=$(gettext "Try again")
# wpa
WW0=$(gettext "New networks will be appended to")
WW1=$(gettext "Here is your")
WW2=$(gettext "restarting the network process")
# start wireless
WS0=$(gettext "Starting the wireless service")
# check
CKL0=$(gettext "Checking connection")
CKL1=$(gettext "Connection is successful")
# manage
MPL0=$(gettext "has not configured your network")
MPL1=$(gettext "Only 1 network configured. Nothing to do.")
MPL2=$(gettext "Choose the number of the network you want as number 1 priority.")
MPL3=$(gettext "is invalid, try again")
MPL4_0=$(gettext "You chose")
MPL4_1=$(gettext "network for number 1 priority.")
MPL5=$(gettext "For more granular control of priority you can manually edit")
MPL6_0=$(gettext "with")
MPL6_1=$(gettext "text editor.")
MPL7=$(gettext "Would you like to do so?")
MPL8=$(gettext "not editing")
# create startup
CSL0_0=$(gettext "Start file")
CSL0_1=$(gettext "exists already")
CSL1=$(gettext "Would you like to start the network at boot?")
CSL2_0=$(gettext "Would you like to make")
CSL2_1=$(gettext "the default connection tool?")
CSL3=$(gettext "is now the default network connection tool")
CSL4_0=$(gettext "not using")
CSL4_1=$(gettext "as default")
# main
MML0=$(gettext "networks have not been configured for start at boot")
MML1=$(gettext "please reconfigure with")
MML2=$(gettext "status")
MML3=$(gettext "Encryption")
MML4=$(gettext "wpa_supplicant failed to start.")

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
_ls() {
	busybox ls "$@"
}
_ifconfig() {
	busybox ifconfig "$@"
}
_head() {
	busybox head "$@"
}
_tail() {
	busybox tail "$@"
}
_rev() {
	busybox rev
}
_cut() {
	busybox cut "$@"
}
_wc() {
	busybox wc "$@"
}

_cp() {
	busybox cp "$@"
}

#----------------------------colours------------------------------------
_yellow() {
	_echo -e "\e[1;33m$@\e[0m"
}

_white() {
	_echo -e "\e[1m$@\e[0m"
}

_white_tab() {
	_echo -en "\e[1m$@\t\e[0m"
}

_green() {
	_echo -e "\e[1;32m$@\e[0m"
}

_light_red() {
	_echo -e "\e[1;91m$@\e[0m"
}

_light_blue() {
	_echo -e "\e[1;96m$@\e[0m"
}

#----------------------------functions----------------------------------
# blurb
_welcome() {
	#clear
	_light_blue "$WELCOME"
	_echo
}

# error
_err() {
	_light_red "$@"
	exit 1
}

# help
_help() {
	_echo -e "$U0:
\t${UL1_0} \e[1;33m$prog\e[0m ${UL1_1}
\t${UL2}
\t${UL3}

Options:"
	_yellow "\t-h | --help: $UL4"
	_yellow "\t-m: $UL5"
	_yellow "\t-r: $UL6"
	_yellow "\t-d: $UL7"
	_yellow "\t-s: $UL8"
	_yellow "\t-l: $UL9"
	_yellow "\t-v: $UL10"
	_echo
	_echo -e "${UL11}:"
	_yellow "\t$prog <essid> <passkey>"
	_echo
	_echo -e \
		"\t${UL12}
\t${UL13}"
	exit 0
}

# check current connection
check_con() {
	_route | while read result
	do
		if [ "${result:0:7}" = 'default' ] ;then
			inface=`_echo $result | _rev | _cut -d ' ' -f1 | _rev`
			[ -n "$inface" ] && _echo -n $inface > ${TMPDIR}/inface && \
				break
		fi
	done
	[ -f ${TMPDIR}/inface ] && inface=`_cat ${TMPDIR}/inface`
	if [ -n "$inface" ] ;then
		iface=$inface # global
		_light_blue "$CL0 $inface."
		sleep 3
		return 0
	else
		_light_red "$CL1"
		rm -rf /var/run/wpa_supplicant/ # precaution
		sleep 2
		return 1
	fi
}

# setup ifaces
set_ifaces() {
	local dont_write=0
	if [ -f /etc/network/interfaces ] ;then # probably not there
		_yellow "$SIL0"
		_white "$SIL1
$SIL2"
		_yellow "$SIL3 y/n"
		read owrite
		case $owrite in
			y*|Y*) 
				mv /etc/network/interfaces /etc/network/interfaces.bak
				_echo "$SIL4"
			;;
			*)dont_write=1
			;; # don't overwrite
		esac
	fi
	
	for ifc in `_ls /sys/class/net`
	do
		case $ifc in
			lo|tun*) continue ;;
			*) _ifconfig $ifc up
			[ -d /etc/network ] || mkdir -p /etc/network
			[ $dont_write -eq 0 ] && \
				_cat >> /etc/network/interfaces <<EOW
auto $ifc
	iface $ifc inet manual

EOW
			if iwconfig $ifc >/dev/null 2>&1 ;then
				_echo -n $ifc > ${TMPDIR}/ifce
				[ $dont_write -eq 0 ] && _echo -en \
				"\twpa-conf ${CONFDIR}/wpa_supplicant.conf\n" \
				>> /etc/network/interfaces
			fi
		;;
		esac
	done
	return 0
}

# scan the airwaves for networks
get_essids() {
	[ -n "$1" ] && interface=$1 || interface=$iface
	_white "$SCL0 $interface .."
	iwlist $interface scan 2>&1 | while read line 
	do
		x=${line/\"/}
		x=${x/\"/}
		x=${x/=/:}
		if [ "${x:0:6}" = 'ESSID:' ] ;then
			ess="${x##*:}"
			[ "${ess:0:3}" = 'x00' ] && x=${x/x00*/(hidden)}
			[ "${ess}" = '' ] && x=${x}'(hidden)'
			found_essid=$x
		fi
		[ "${x:0:8}" = 'Quality:' ] && qual=${x%% *}
		[ "${x:0:15}" = 'Encryption key:' ] && key_state=${x#* }
		[ "${x:0:5}" = 'Mode' ] && continue
		# as soon as we found the essid we print it
		[ -n "$found_essid" ] && \
			_echo -e "$found_essid\t\t$qual\t$key_state" >> \
				${TMPDIR}/scanlist
		# unset found_essid for next iteration
		[ -n "$found_essid" ] && unset found_essid && continue
	done
}

# display essids and choose
display_networks() {
	local cnt=1
	local choice
	[ -f "${TMPDIR}/scanlist" ] || \
		_err "$SCL1"
	_green \
	  "$SCL2"
	_echo
	while true
	do
		while read line
		do
			_white_tab "${cnt}."; _yellow  "$line"
			cnt=$(($cnt + 1))
		done < ${TMPDIR}/scanlist
		read choice
		case $choice in
			*[0-9])
			if [ $choice -lt 1 -o $choice -gt $cnt ];then
				_light_red "$choice $SCL3"
				cnt=1
				continue
			else
			  essid="`_head -n${choice} ${TMPDIR}/scanlist | _tail -n1`"
			  keystate=`_echo ${essid} | _rev | _cut -d ':' -f1 | _rev`
			  essid="${essid/Quality*/}"
			  essid="${essid#*:}"
			  [ "${essid:0:8}" = '(hidden)' ] && hidden=0 && \
					enter_hidden_essid
			  _green "$SCL4"
			  break
			fi
			;;
			*)
				_light_red "$choice $SCL3"
				cnt=1
				continue
			;;
		esac
	done
}

# hidden essid
enter_hidden_essid() {
	_yellow "$HL0"
	read entry
	_green "$HL1_0 $entry $HL1_1"
	essid=$entry
}

# pass key
enter_psk() {
	clear
	while true	# dialog
	do
		dialog --title "$PL0" \
		--clear \
		--insecure \
		--passwordbox "$PL1" 10 30 2> ${TMPDIR}/pw
		ret=$?
		# make decision
		case $ret in
			0)passkey=$(_cat ${TMPDIR}/pw)
				break;;
			*)clear
				_light_red "$PL2"
				sleep 2
				continue;;
		esac
	done
	clear
}

# construct wpa_supplicant.conf
# params $1=essid, $2=psk
write_wpa_conf() {
	local EXISTS=false
	local WPA_FILE=${CONFDIR}/wpa_supplicant.conf
	[ -n "$2" ] && PASSKEY_STR="psk=\"$2\"" || \
							PASSKEY_STR="key_mgmt=NONE"
	[ -f "$WPA_FILE" ] && \
	_cp $WPA_FILE ${WPA_FILE}.bak && \
	EXISTS=true
	if [ "$EXISTS" = 'false' ] ;then
		# create
		_echo "ctrl_interface=/var/run/wpa_supplicant
update_config=1
" > $WPA_FILE
		_echo 'network={' >> $WPA_FILE
		_echo -e "\tssid=\"$1\"" >> $WPA_FILE
		[ "$hidden" = '0' ] && _echo -e "\tscan_ssid=1" >> $WPA_FILE
		_echo -e "\t${PASSKEY_STR}" >> $WPA_FILE
		_echo -e "\tpriority=$prio" >> $WPA_FILE
	else
		# append
		_light_blue "$WW0 $WPA_FILE"
		n=0
		while read net
		do
			[ "${net:0:7}" = 'network' ] && n=$(($n + 1))
		done < $WPA_FILE
		_echo 'network={' >> $WPA_FILE
		_echo -e "\tssid=\"$1\"" >> $WPA_FILE
		[ "$hidden" = '0' ] && _echo -e "\tscan_ssid=1" >> $WPA_FILE
		_echo -e "\tpsk=\"$2\"" >> $WPA_FILE
		_echo -e "\tpriority=$(($prio + $n))" >> $WPA_FILE
	fi
	_echo '}' >> $WPA_FILE
	
	_yellow "$WW1 $WPA_FILE"
	WCONF=`_cat $WPA_FILE`
	_white "$WCONF"
	sleep 2
	if [ "$EXISTS" = 'true' ] ;then
		_yellow "$WW2"
		if [ -e "/etc/init.d/01${prog}" ];then
			/etc/init.d/01${prog} restart
			exit $?
		fi
	fi
}

# start dhcpcd
dhcpcd_start() {
	DHCPCD=`pidof dhcpcd` # check if running
	[ -n "$DHCPCD" ] && kill -9 $DHCPCD
	dhcpcd
}

# stop wpa - precaution
wpa_stop() {
	WPID=`pidof wpa_supplicant`
	if [ -n "$WPID" ] ;then
		for i in $WPID
		do 
			kill -9 $i
		done
	fi
}

# start wpa
wpa_start() {
	wpa_stop
	iface=$1
	_echo iface: $iface
	_green "$WS0 .."
	sleep 1
	wpa_supplicant -B -Dwext -i $iface \
		-c ${CONFDIR}/wpa_supplicant.conf
}

# check we have default in 'route'
check_router() {
	_echo
	_light_blue "$CKL0"
	t=0
	s=1
	while [ $t -le 15 ] # may need time
	do
		_route | while read result
		do
			if [ "${result:0:7}" = 'default' ] ;then
				_light_blue "$CKL1"
				s=0
				break
			fi
		done
		[ $s -eq 0 ] && break
		sleep 1
		t=$(($t + 1))
	done
}

# manage priority if multiple networks
manage_priority() {
	choose=''
	local SUP_FILE=${CONFDIR}/wpa_supplicant.conf
	[ ! -e "$SUP_FILE" ] && _err "$prog $MPL0"
	local net_n=0
	_cp $SUP_FILE ${SUP_FILE}.before_prio_edit
	while read networks
	do
		[ "${networks:0:7}" = 'network' ] && net_n=$(($net_n + 1))
	done < $SUP_FILE
	
	[ $net_n -le 1 ] \
		&& _white "$MPL1"
	_yellow \
	  "$MPL2"
	while true
	do
		pr=1
		rm -f ${TMPDIR}/bbw_*
		while read ent
		do
			[ -z "$ent" ] && continue
			[ "${ent:0:14}" = 'ctrl_interface' \
			-o "${ent:0:13}" = 'update_config' ] && \
				echo "$ent" >> ${TMPDIR}/bbw_hold || \
				echo ${ent} >> ${TMPDIR}/bbw_net${pr}
			[ "${ent:0:4}" = 'ssid' ] && \
				x=${ent#*=} && x=${x/\"/} && echo "${pr} ${x/\"/}" >> \
					${TMPDIR}/bbw_list
			[ "${ent:0:1}" = '}' ] && pr=$(($pr + 1))
		done < $SUP_FILE
		cat ${TMPDIR}/bbw_list
		read choose
		case $choose in
			*[0-9])
			if [ $choose -lt 1 -o $choose -gt $((pr - 1)) ];then
				echo "$choose $MPL3"
				pr=1
				continue
			else
				break
			fi
			;;
			*)
				echo "$choose $MPL3"
				pr=1
				continue
			;;
		esac
	done
	
	while read opt
	do 
		[ "${opt:0:1}" = "$choose" ] && \
		_echo -n "${opt#*' '}" > ${TMPDIR}/bbw_choice && \
		_green "$MPL4_0 ${opt#*' '} $MPL4_1"
	done < ${TMPDIR}/bbw_list
	z=`cat ${TMPDIR}/bbw_choice`
	z="ssid=\"${z}\""
	numchars=`_echo $z | _wc -c`
	numchars=$(($numchars - 1)) # remove line end char
	NEW_CONF=${TMPDIR}/wpa_supplicant.conf
	cat ${TMPDIR}/bbw_hold > $NEW_CONF
	_echo >> $NEW_CONF
	
	NP=1
	ONP=0
	for sups in ${TMPDIR}/bbw_net[0-9]*
	do
		while read new_ent
		do
			if [ "${new_ent:0:7}" = 'network' ] ;then
				echo $new_ent >> $NEW_CONF
			fi
			
			if [ "${new_ent:0:${numchars}}" = "$z" ] ;then
				echo -e "\t${new_ent}" >> $NEW_CONF
				ONP=$NP
				NP=1
			elif [ "${new_ent:0:4}" = 'ssid' \
				-a "${new_ent:0:${numchars}}" != "$z" ] ;then
				echo -e "\t${new_ent}" >> $NEW_CONF
				[ $ONP -ne 0 ] && NP=$ONP
				NP=$(($NP + 1))
				ONP=0
			fi
			[ "${new_ent:0:9}" = 'scan_ssid' ] && \
				echo -e "\t${new_ent}" >> $NEW_CONF
			[ "${new_ent:0:3}" = 'psk' ] && \
				echo -e "\t${new_ent}" >> $NEW_CONF
			[ "${new_ent:0:8}" = 'key_mgmt' ] && \
				echo -e "\t${new_ent}" >> $NEW_CONF
			if [ "${new_ent:0:8}" = 'priority' ] ;then
				echo -e "\tpriority=$NP" >> $NEW_CONF
			fi
			[ "${new_ent:0:1}" = '}' ] && echo $new_ent >> $NEW_CONF
		done < $sups
	done
	# sort out an editor
	ED=''
	if [ $DISPLAY ] ;then
		for editor in medit leafpad geany
		do
			type $editor >/dev/null 2>&1 && ED=$editor && break
		done
	else
		for nox_ed in 'busybox vi' mp nano
		do
			type $nox_ed >/dev/null 2>&1 && ED=$nox_ed && break
		done
	fi
	
	[ -z "$ED" ] && _cp -f $NEW_CONF $SUP_FILE && return
	_yellow "$MPL5
$NEW_CONF $MPL6_0 $ED $MPL6_1
$MPL7 (y/n)"
	read edit
	case $edit in
		y*|Y*) $ED $NEW_CONF ;;
		*) _echo "$MPL8" ;;
	esac
	_cp -f $NEW_CONF $SUP_FILE
}

# create startup file
_init() {
	local init_file=/etc/init.d/01${prog}
	sleep 2
	[ -e "$init_file" ] && \
		_light_red "$CSL0_0 $init_file $CSL0_1" && return
 	_yellow "$CSL1 (y/n)"
	read startup
	case $startup in
		y*|Y*)_green 'OK';;
		*)return;;
	esac
	_cat > $init_file <<EOI
#!/bin/ash

IFACE=''

#------------------------busybox commands-------------------------------
_echo() {
	busybox echo "\$@"
}
_cat() {
	busybox cat "\$@"
}
_ls() {
	busybox ls "\$@"
}
_ifconfig() {
	busybox ifconfig "\$@"
}
#-------------------------------func------------------------------------
set_iface() {
	for ifc in \`_ls /sys/class/net\`
	do
		case \$ifc in
			lo|tun*) continue ;;
			*) _ifconfig \$ifc up
			iwconfig \$ifc >/dev/null 2>&1 && \
_echo -n \$ifc > /tmp/iface
		;;
		esac
	done
}

_start_me() {
	_echo starting
	IFACE=\`_cat /tmp/iface\`
	wpa_supplicant -B -Dwext -i \$IFACE \
-c ${CONFDIR}/wpa_supplicant.conf
	dhcpcd
}

_stop_me() {
	_echo stopping
	dhcpcd -k \$IFACE
	WPID=\`pidof wpa_supplicant\`
	if [ -n "\$WPID" ] ;then
		for i in \$WPID
		do 
			kill -9 \$i
		done
	fi
}

#-------------------------------main------------------------------------
set_iface
case \$1 in
start) _start_me
;;
stop) _stop_me
;;
restart) _stop_me; sleep 2 ;_start_me
;;
esac
EOI
	chmod 0755 $init_file
	_yellow \
	  "$CSL2_0 $prog $CSL2_1 (y/n)"
	  read default
	 case $default in
		y*|Y*) _cat > /usr/local/bin/defaultconnect <<EOC
#/bin/sh
exec bbwireless.wrap.sh "\$@"
EOC
	chmod 755 /usr/local/bin/defaultconnect
		_green "$prog $CSL3"
		;;
		*)_echo "$CSL4_0 $prog $CSL4_1"
		;;
	esac
}

_list() {
	_yellow 'list:'
	_cat ${CONFDIR}/wpa_supplicant.conf | while read list_net
	do
		case $list_net in
			ssid=*)_white ${list_net##*=};;
			*)continue ;;
		esac
	done
}

# trap cleanup
_trap() {
	rm -rf ${TMPDIR}
	_yellow "$END"
	exit
}

# gotta love ash
_trap_exit() {
	rm -rf ${TMPDIR}
	_yellow 'Finished!'
	exit
}

#-------------------------------main------------------------------------

trap _trap 2      # ctrl C
trap _trap_exit 0 # normal exit

if [ -n "$1" ];then
	case $1 in
		-h|--help)_help;;
		-m)manage_priority && exit $? ;;
		-r)[ -e "/etc/init.d/01${prog}" ] || \
			_err "${MML0},
$MML1 $prog -s"
			/etc/init.d/01${prog} restart  && exit 0;;
		-d)[ -e "/etc/init.d/01${prog}" ] || \
			_err "${MML0},
$MML1 $prog -s"
			/etc/init.d/01${prog} stop  && exit 0;;
		-s)_init && exit 0;;
 		-l)_list && exit 0;;
 		-v)_echo $prog-$ver && exit 0;;
		?*)[ -z "$2" ] && _help
			write_wpa_conf $1 $2
			_echo done && exit $?;;
	esac
fi

check_con; connnect_status=$?
_echo "${MML2}: $connnect_status"
set_ifaces
iface=`_cat ${TMPDIR}/ifce`
get_essids $iface
_welcome
display_networks
_green "$MML3 $keystate"
case $keystate in
	*on)enter_psk
		write_wpa_conf $essid $passkey ;;
	*off)write_wpa_conf $essid ;;
esac
echo $iface
wpa_start $iface || _err "$MML4"
dhcpcd_start
check_router
_init
