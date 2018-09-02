#!/bin/bash

#Enable verbose output
set -x

#Fixed paths
IMGLOCATION="/var/lib/libvirt/images"

#Used for testing
#VMs=( "debian9-openttd" "debian9-nico" )

#List all VMs
VMs=( "debian9-mailcow" "debian9-apache2" "debian9-gitlab" "debian9-discordjockey" "debian9-minecraft" "debian9-openttd" "debian9-teamspeak" "debian9-openvpn" "debian9-proftpd" "debian9-netdata" "debian9-guacamole" "win10-assettocorsa" "debian9-onlyoffice" )

#Get times and dates
now="$(date '+%F_%T:%N')"
today="$(date '+%F')"

#Folder to remove locally -> Keep the last two days locally
olddatelocal="$(date -d '2 days ago 13:00' '+%F')"

#Folder to remove remotely -> Keep the last seven days remotely
olddateremote="$(date -d '7 days ago 13:00' '+%F')"

#Get paths from dates
LOCALDIR="/srv/vmdata/backup/$today"
REMOTEDIR="/backup/$today/"
OLDLOCALDIR="/srv/vmdata/backup/$olddatelocal"
OLDREMOTEDIR="/backup/$olddateremote/"
LOGFILE="/root/backup_logs/$now.log"

#Create logfile directory if it does not exist
mkdir -p /root/backup_logs

#Log script output
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>$LOGFILE 2>&1

#Should not exist, but in case it does, remove it
#Locally
rm -r $LOCALDIR

#Remotely
lftp -u u180771,password sftp://u180771.your-backup.de << EOF
rm -r $REMOTEDIR
quit
EOF


#Backup all VMs to directory
for i in "${VMs[@]}"
do
	tmp=$(virsh list --all | grep " $i " | awk '{ print $3}')
	if ([ "$tmp" == "running" ])
	then
		/root/scripts/kvm-backup.sh -t $LOCALDIR $i
	else
		mkdir "$LOCALDIR/$i"
		mkdir "$LOCALDIR/$i/backup-0"
		cp "$IMGLOCATION/$i.qcow2" "$LOCALDIR/$i/backup-0/"
		virsh dumpxml "$i" > "$LOCALDIR/$i/backup-0/$i.xml"
	fi
done

#Save iptables rules
iptables-save > "$LOCALDIR/rules.v4"

#Copy logfile to backup folder
cp $LOGFILE $LOCALDIR

#Copy backup to backup space
scp -r $LOCALDIR u180771@u180771.your-backup.de:$REMOTEDIR

#Remove old backup locally
rm -r $OLDLOCALDIR

#Remove old backup remotely
lftp -u u180771,password sftp://u180771.your-backup.de << EOF
rm -r $OLDREMOTEDIR
quit
EOF

