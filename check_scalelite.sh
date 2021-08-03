#!/bin/bash

#Plugin return codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

#Version anzeigen
print_version() {
 echo "Script-Version: 1.1"
 echo "Erstellt von: M. Heinrich"
 echo "Erstellt am: 01.07.2021"
 echo "Zuletzt Geändert am: 03.08.2021"
 echo "Versions-Historie:"
 echo "Version 1.0: Erstmalige Erstellung"
 echo "Version 1.1.: Warnung, wenn Server offline, oder deaktiviert wurde; Warnungen werden nun ganz oben angezeigt"
}

#Hilfe anzeigen
print_help() {
 print_version
 echo ""
 echo "Usage: ./check_scalelite.sh -w <Meetings,User,Video> -c <Meetings,User,Video>"
 echo "Example: ./check_scalelite.sh -w 10,150,25 -c 20,250,50"
 echo ""
 echo "Parameter:"
 echo "-w STRING"
 echo "   Warnung: Anzahl Meetings,User,Video"
 echo "-c STRING"
 echo "   Kritisch: Anzahl Meetings,User,Video"
 exit $STATE_OK
}

#Script Übergabeparameter Variable zuordnen
while getopts w:c:hv OPT
do
 case $OPT in
  w) WARNING=$OPTARG ;;
  c) CRITICAL=$OPTARG ;;
  h) print_help
     exit $STATE_OK ;;
  v) print_version
     exit $STATE_OK ;;
 esac
done

#Wenn Warnparameter anegeben wurden, diese versch. Variablen zugeordnet
if [[ -v WARNING ]]; then
 WARNING_MEETINGS=$(echo $WARNING | cut -d "," -f1)
 WARNING_USERS=$(echo $WARNING | cut -d "," -f2)
 WARNING_VIDEO=$(echo $WARNING | cut -d "," -f3)
fi

if [ $OPT="c" ] 2>/dev/null; then
 CRITICAL_MEETINGS=$(echo $CRITICAL | cut -d "," -f1)
 CRITICAL_USERS=$(echo $CRITICAL | cut -d "," -f2)
 CRITICAL_VIDEO=$(echo $CRITICAL | cut -d "," -f3)
fi

#Scalelite-Status-Abfrage
 scalelitelist=$(sudo docker exec -i scalelite-api ./bin/rake status | grep video > /tmp/check_scalelite.log)
 scalelitelist="/tmp/check_scalelite.log"

#Lese jede Zeile aus der Datei /tmp/check_scalelite.log und übergebe die einzelnen Werte in Variable
count=0
while IFS= read -r line
do
 count=$((count+1))
 state="state.$count"
 status="status.$count"
 meetings="meetings.$count"
 users="users.$count"
 video="video.$count"
 largemeeting="largmeeting.$count"
 servername_value=$(echo $line | awk '{ print $1 }' | cut -d "." -f1)
 servername_value=$servername_value.xxx.de

 servername_state_value=$(echo $line | awk '{ print $2 }')
 servername_status_value=$(echo $line | awk '{ print $3 }')
 servername_meetings_value=$(echo $line | awk '{ print $4 }')
 servername_users_value=$(echo $line | awk '{ print $5 }')
 servername_largemeeting_value=$(echo $line | awk '{ print $6 }')
 servername_video_value=$(echo $line | awk '{ print $7 }')
 #Ausgabe für Icinga2
 echo "Servername: $servername_value, State: $servername_state_value, Status: $servername_status_value, Anzahl Meetings: $servername_meetings_value, Benutzer: $servername_users_value, Video: $servername_video_value, Groeßtes Meeting: $servername_largemeeting_value" >> /tmp/check_scalelite_status.log
 if [[ $servername_state_value != "enabled" ]]; then
  echo "Warnung! Der Server $servername_value befindet sich im Status $servername_state_value (Serverstatus:  $servername_status_value)" >> /tmp/check_scalelite_description_warning.log
  STATE=$STATE_WARNING
  fi
 if [[ $servername_status_value != "online" ]]; then
  echo "Warnung! Der Server $servername_value ist $servername_status_value" >> /tmp/check_scalelite_description_warning.log
  STATE=$STATE_WARNING
  fi
 if [[ -v WARNING ]]; then
  if [[ $servername_meetings_value -ge $WARNING_MEETINGS || $servername_users_value -ge $WARNING_USERS || $servername_video_value -ge $WARNING_VIDEO ]]; then
   echo "Warnung! Ein Warnwert für den Server $servername_value wurde überschritten" >> /tmp/check_scalelite_description_warning.log
   STATE=$STATE_WARNING
  fi
 fi
 if [[ -v CRITICAL ]]; then
  if [[ $servername_meetings_value -ge $CRITICAL_MEETINGS || $servername_users_value -ge $CRITICAL_USERS || $servername_video_value -ge $CRITICAL_VIDEO ]]; then
   echo "Kritisch! Ein kritischer Wert für den Server $servername_value wurde überschritten" >> /tmp/check_scalelite_description_critical.log
   STATE=$STATE_CRITICAL
  fi
 fi
 if [[ $servername_status_value != "online" ]]; then
   echo "Warnung! Der Server $servername_value ist nicht online!" >> /tmp/check_scalelite_description_online.log
   STATE=$STATE_WARNING
 fi

#Perfomance-Data
#Beim Servernamen wird xxx.de entfernt, da sonst Icinga2 die Performance-Werte im Graphite nicht darstellen kann
servername_value=$(echo "${servername_value/.xxx.de/""}")
echo "|$servername_value.meetings=$servername_meetings_value;$WARNING_MEETINGS;$CRITICAL_MEETINGS" ;
echo "|$servername_value.users=$servername_users_value;$WARNING_USERS;$CRITICAL_USERS" ;
echo "|$servername_value.videos=$servername_video_value;$WARNING_VIDEO;$CRITICAL_VIDEO" ;
echo "|$servername_value.large=$servername_largemeeting_value" ;

done < "$scalelitelist"

#Ausgabe der Warnmeldung an Icinga2
if [[ -e /tmp/check_scalelite_description_warning.log ]]; then
cat /tmp/check_scalelite_description_warning.log
STATE=$STATE_WARNING
fi

if [[ -e /tmp/check_scalelite_description_critical.log ]]; then
cat /tmp/check_scalelite_description_critical.log
STATE=$STATE_CRITICAL
fi

if [[ -e /tmp/check_scalelite_description_online.log ]]; then
cat /tmp/check_scalelite_description_online.log
STATE=$STATE_WARNING
fi

if [[ -e /tmp/check_scalelite_status.log ]]; then
cat /tmp/check_scalelite_status.log
fi

#Alle LOGS löschen
sudo rm -rf /tmp/check_scalelite*.log

exit $STATE
