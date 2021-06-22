#!/bin/bash

# Author: Ullrich Weichert
# Scriptversion 0.8
# last edit: 13.07.2016
# by: UWe

######Ziel des Scripts##############
# Automatisches Installieren der Zabbix-Agenten an alle übergebene Linuxserver

######Pruefen ob das Script schon laeuft
pname="$(echo $0|sed 's@.*/@@')"
semname="${pname}.pid"
semfile="/var/run/${semname}"
if [ -f "${semfile}" ]; then
        pid="$(cat "${semfile}")"
        if [ -f "/proc/${pid}/stat" ]; then
                id="$(cat /proc/$$/stat|awk '{print $2}')"
                if [ -n "$(grep -P "\Q${id}\E" "/proc/${pid}/stat")" ]; then
                        echo "$(date): $pname is already running!"
                        exit 1
                fi
        fi
fi
echo $$ > "${semfile}"

######Variablen#####################
RepoFile2Down="http://download.opensuse.org/repositories/server:/monitoring:/zabbix/SLE_11/server:monitoring:zabbix.repo"
InstallRepo="server:monitoring:zabbix.repo"
Package="zabbix30-agent"
ZabbixConf="/etc/zabbix/zabbix-agentd.conf"
HOSTMETADATA="ncg-linux"
ZabbixSERVER="10.60.40.11"


### Check if we got all the binarys we need
tmpfile="$(mktemp)"
chmod +x "${tmpfile}"
for cmd in rm echo ssh cat cp wget zypper service; do
        echo -e "#!/bin/bash\n${cmd}=\"\$(which ${cmd})\"\nif ! [ -x \"\${${cmd}}\" ]; then\n\techo \"ERROR: Can't find '${cmd}' ('\${${cmd}}')\"\n\texit 1\nfi" > "${tmpfile}"
        source "${tmpfile}"
        if [ "$?" -gt "0" ]; then
                rm "${tmpfile}"
                echo "${cmd} is required but not found!"
                exit 5
                fi
done
$rm "${tmpfile}"
### EOF binary check

### Mainprogram

while [ $# -gt 0 ] ### Durchlaeufe gemäß der übergebenen Werte
do		
        $echo -e "\n---------\nDownload Repo auf ${1}\n---------\n"
        $ssh root@$1 "$wget ${RepoFile2Down}"
        sleep 2
        $echo -e "\n---------\nInstall Repo auf ${1}\n---------\n"
        $ssh root@$1 "$zypper addrepo -r ${InstallRepo}"

        $echo -e "\n---------\nZabbix-Repo wird auf ${1} refreshed.\n---------\n"
        $ssh root@$1 "$zypper --non-interactive --gpg-auto-import-keys refresh -r server_monitoring_zabbix"

        $echo -e "\n---------\nInstallation vom ${Package} auf ${1}.\n---------\n"
        $ssh root@$1 "$zypper --non-interactive install ${Package}"
        $ssh root@$1 "$service zabbix-agentd stop"

        $echo -e "\n---------\nSichern und anpassen der ${Package} Konfiguration auf ${1}.\n---------\n"
        $ssh root@$1 "$cp ${ZabbixConf} ${ZabbixConf}.ORIG"
        $ssh root@$1 "echo 'PidFile=/var/run/zabbix/zabbix-agentd.pid' > ${ZabbixConf}"
        $ssh root@$1 "echo 'LogFile=/var/log/zabbix/zabbix-agentd.log' >> ${ZabbixConf}"
        $ssh root@$1 "echo 'LogFileSize=5' >> ${ZabbixConf}"
        $ssh root@$1 "echo 'DebugLevel=3' >> ${ZabbixConf}"
        $ssh root@$1 "echo 'EnableRemoteCommands=1' >> ${ZabbixConf}"
        $ssh root@$1 "echo 'Server=${ZabbixSERVER}'  >> ${ZabbixConf}"
        $ssh root@$1 "echo 'ServerActive=${ZabbixSERVER}' >> ${ZabbixConf}"
        $ssh root@$1 "echo 'Hostname=${1}' >> ${ZabbixConf}"
        $ssh root@$1 "echo 'HostMetadata=${HOSTMETADATA}' >> ${ZabbixConf}"
        $ssh root@$1 "echo 'UnsafeUserParameters=1' >> ${ZabbixConf}"
		$ssh root@$1 "echo 'Timeout=30' >> ${ZabbixConf}"
		
		$echo -e "\n---------\nPacke ${Package} auf ${1} in den autostart.\n---------\n"
		$ssh root@$1 "chkconfig zabbix-agentd on"
		
        $echo -e "\n\nKontrollausgabe der ${ZabbixConf} auf ${1}:\n---------"
        $ssh root@$1 "$cat ${ZabbixConf}"
        $echo -e "---------\n"

        $echo -e "\n---------\nWenn alles Ok dann warten, ansonsten Abbrechen! STRG-C\n---------\n"

        sleep 15

        $echo -e "\n\n---------\nStarte ${Package} auf ${1}:\n---------"
        $ssh root@$1 "$service zabbix-agentd start"

        $echo -e "\n\n---------\nCleaning up...\n---------\n"
        $ssh root@$1 "rm ${InstallRepo}"

        shift
done;
