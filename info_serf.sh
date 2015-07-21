#!/bin/bash
DIRECTORY="$(pwd)"
SQLITE3="/usr/bin/sqlite3"
DATABASEPWD="${DIRECTORY}/db"
DATABASENAME="neighbours.db"
DATABASE="${DATABASEPWD}/${DATABASENAME}"
BACKUP="168"
SERFCONF="/etc/avahi-ps-serf.conf"
GTCONF="/etc/getinconf-client.conf"

readSerf() {
	ADVERTISE_IP=""
	test -f $SERFCONF && . $SERFCONF
	test -f $GTCONF && . $GTCONF
	[ -z "$ADVERTISE_IP" ] && ADVERTISE_IP=$(ip addr show dev $INTERNAL_DEV|grep "global.* $INTERNAL_DEV\$"|awk '{print $2}'|awk -F "/" {'print $1'})
	SerfNode="$ADVERTISE_IP"
	date=$(date +%s)
	while read i
	do
		ip=$(echo "$i"|cut -d " " -f 2)
		status=$(echo "$i"|cut -d " " -f 3)
		services=$(echo "$i"|cut -d " " -f 4| sed "s/^services=//g")
		[ ! -z "$services" ] && services=$(echo $services|base64 -d|bunzip2|sed s/\"/\'/g)
		echo "INSERT INTO neigh VALUES (NULL, \"$SerfNode\", \"$ip\", \"$status\", \"$services\", $date);"|$SQLITE3 $DATABASE

	done < <(/opt/serf/serf members|grep -v test= |sed "s/\s\+/ /g")
}

createDB() {
	[ ! -f "$DATABASE" ] && {
		mkdir -p ${DATABASEPWD}
		echo "CREATE TABLE neigh(id integer primary key autoincrement, serfnode STRING, ip STRING, status STRING, services TEXT, Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);" | $SQLITE3 $DATABASE ;
	}
}

compressDB() {
	[ -f "$DATABASE" ] && {
		bzip2 $DATABASE
	}
}

uncompressDB() {
	[ -f "$DATABASE.bz2" ] && {
		bunzip2 $DATABASE.bz2
	}
}


uncompressDB
# If Database not exist... create.
createDB
# Read serf information and save in Database.
readSerf
compressDB
