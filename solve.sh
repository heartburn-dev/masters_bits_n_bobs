#!/bin/bash

# Works against brute forces with:
# crowbar (rockyou must be converted to utf-8 for testing)
# iconv -f ISO-8859-1 -t UTF-8 /usr/share/wordlists/rockyou.txt > rockyou_utf8.txt
#
# hydra
# hydra -l firefly -P /usr/share/wordlists/rockyou.txt 192.168.43.189 rdp -V -f -I
#
# This script sits on a network and watches RDP traffic toward the 
# MONITORING_IP address on port 3389, in order to detect a BF attempt.
# Checks the size of the tcpdump log regularly and assumes and sudden increase
# in traffic in a short space of time is indicative of a brute force attempt.
# Once detected, watches for a packet seq number in combination with a FIN flag ([F.])
# that is higher than 2000 to signify a valid login.
# Generally, in our testing, failed logins had only 14 packets sent from the attacker
# to the target resulting in a max seq number of 1400~ whereas a valid login using 
# a brute force tool had upward of 3000 as the FIN packet's seq number.

# TODO
# Generate a dynamic log file for each monitor so we keep logs
# At the moment, we're overwriting the log each time.

# https://github.com/carlospolop/PEASS-ng/blob/master/linPEAS/builder/linpeas_parts/linpeas_base.sh
C=$(printf '\033')
RED="${C}[1;31m"
GREEN="${C}[1;32m"
YELLOW="${C}[1;33m"

# Check if root. We need this for packet capture purposes
# https://askubuntu.com/questions/258219/how-do-i-make-apt-get-install-less-noisy
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Globals -> LIMIT is the difference in (bytes) that we're looking at the log file
# increasing by over 3 seconds. Play to suit needs.
MONITOR_IP="192.168.43.189"
LIMIT=40000
LOG="/opt/dumpsolve/log.txt"
BRUTE_ATTEMPT=false

# Start monitoring and background the process
tcpdump -i eth0 dst $MONITOR_IP and dst port 3389 -U -w $LOG &


# Once a brute force attempt is detected, attempt to extract the source IP
getAttackerIP() {
	echo $YELLOW"[*] Attack looks like it is coming from: $RED`tcpdump -r $LOG | grep -a '\[F\.\]' | awk {'print $3'} | awk -F '.' 'NF{NF-=1};1' | sed 's/ /./g' | sort -u`"
}

# Check for changes in the packet sequences which may indicate a successful login
checkSuccess() {
	IOC=`tcpdump -r $LOG | grep -a '\[F\.\]' | awk {'print $9'} | sed 's/,//g' | awk '{if ( $1 > 2000 ) print $1}'`
	IOC_CALC=$(($IOC - 1500))
	if [[ $IOC_CALC -gt 0 ]]; then
		notify-send 'WARNING!' "Potential brute force success on $MONITOR_IP! $IOC sequence detected in packet analysis!"
		echo $RED"POTENTIAL BRUTE FORCE SUCCESS.. $IOC sequence detected in packet analysis!"
	fi
}

# Constantly run...
while true; do
	# Get the starting size of the log file 
	STARTING_SIZE=$(ls -la $LOG | awk {'print $5'})
	# Wait...
	sleep 3
	# See if there is any change in log size over the LIMIT (40000)
	NEW_SIZE=$(ls -la $LOG | awk {'print $5'})
	DIFFERENCE=$(($NEW_SIZE-$STARTING_SIZE))
	# If LIMIT exceeded, alert about apotential brute force attack and grab attacker IP
	if [[ $DIFFERENCE -ge $LIMIT ]]; then
		BRUTE_ATTEMPT=true
		printf $RED"[!] Potential Brute Force in Progress!\n"
		getAttackerIP
	else
		printf $GREEN"[*] No attack currently being detected!\n"
	fi
	# Leave this alerting even when the attack stops
	# If Brute force detected, start to check for success packets
	if [[ $BRUTE_ATTEMPT -eq true ]]; then 
		checkSuccess
	fi
done
