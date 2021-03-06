#!/bin/bash

CURDIR="$( cd `dirname "${BASH_SOURCE[0]}"` && pwd )"
source $CURDIR/functions.sh
INSTALLING="observium-client"
HOSTNAME=$(hostname --fqdn)
askbreak "Really? Make sure your hostname ($HOSTNAME) is correct!"

IP=$(ifconfig | grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}')

if [[ $1 == "external" ]]; then
    echo "Using the external IP ($IP) instead of an AutoSSH tunnel."
    EXTERNAL=true
fi

mkdir -p /opt/observium-client/plugins
#link /shared/root/observium-client/local-default /opt/observium-client/local

# fix hostname problem with rsyslog
apt-add-repository -y ppa:tmortensen/rsyslogv7
apt-get update
apt-get install -y rsyslog snmpd xinetd

if [[ -z $EXTERNAL ]]; then
	apt-get install -y autossh
	ufw allow from 127.0.0.1 app "Observium Agent"
	ufw allow from 127.0.0.1 to any port snmp
else
	ufw allow from $OBSERVIUM_SERVER app "Observium Agent"
	ufw allow from $OBSERVIUM_SERVER to any port snmp
fi

echo "*.* @@$OBSERVIUM_SERVER:$RSYSLOG_PORT" > $DIR/etc/rsyslog.d/97-send-to-observium.conf

#link_all_files ${DIR}/etc/rsyslog.d /etc/rsyslog.d

SNMP_COMMUNITY=$(cat /proc/sys/kernel/random/uuid)
store_local_config "SNMP_COMMUNITY" $SNMP_COMMUNITY

if [[ -z $EXTERNAL ]]; then
	if [[ -z ${ConfigArr['SNMP_PORT_LAST']} ]]; then
	    SNMP_REMOTE_PORT=${ConfigArr['SNMP_PORT_START']}
	else
	    SNMP_REMOTE_PORT=$(( ${ConfigArr['SNMP_PORT_LAST']} + 1 ))
	fi
	store_shared_config "SNMP_PORT_LAST" $SNMP_REMOTE_PORT
	store_local_config "SNMP_REMOTE_PORT" $SNMP_REMOTE_PORT
	#remote_ufw_command="ufw allow from 127.0.0.1 app \"Observium Syslog\""
	remote_hosts_set="sudo $DIR/root/observium/add-host-via-ssh.sh $HOSTNAME $IP"
	set_installed observium-client-via-ssh norun
else
	SNMP_REMOTE_PORT=161
	remote_ufw_command="ufw allow from $IP app \"Observium Syslog\""
fi

set_installed observium-client

source $CURDIR/add-ssh-key.sh
echo "Enter your Observium SSH password:"
ssh-copy-id "-p$SSH_PORT observium@$OBSERVIUM_SERVER"

service snmpd restart
service rsyslog restart

ssh observium@$OBSERVIUM_SERVER -p $SSH_PORT "${remote_hosts_set}; ${remote_ufw_command}; /opt/observium/addhost.php $HOSTNAME $SNMP_COMMUNITY v2c $SNMP_REMOTE_PORT tcp"

service autossh-snmp start