#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS/Debian/Ubuntu
#	Description: Cloud Torrent
#	Version: 1.2.2
#	Author: Toyo
#	Translate: najashark
#	Blog: https://doub.io/wlzy-12/
#=================================================

file="/usr/local/cloudtorrent"
ct_file="/usr/local/cloudtorrent/cloud-torrent"
dl_file="/usr/local/cloudtorrent/downloads"
ct_config="/usr/local/cloudtorrent/cloud-torrent.json"
ct_conf="/usr/local/cloudtorrent/cloud-torrent.conf"
ct_log="/tmp/ct.log"
IncomingPort="50007"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[INFO]${Font_color_suffix}"
Error="${Red_font_prefix}[ERR]${Font_color_suffix}"
Tip="${Green_font_prefix}[TIP]${Font_color_suffix}"

#Check system
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	bit=$(uname -m)
}
check_installed_status(){
	[[ ! -e ${ct_file} ]] && echo -e "${Error} Cloud Torrent Not Installed, Please check !" && exit 1
}
check_pid(){
	PID=$(ps -ef | grep cloud-torrent | grep -v grep | awk '{print $2}')
}
check_new_ver(){
	ct_new_ver=$(wget --no-check-certificate -qO- https://github.com/jpillora/cloud-torrent/releases/latest | grep "<title>" | sed -r 's/.*Release (.+) · jpillora.*/\1/')
	if [[ -z ${ct_new_ver} ]]; then
		echo -e "${Error} Cloud Torrent Failed to get the latest version, please manually get the latest version number[ https://github.com/jpillora/cloud-torrent/releases ]"
		stty erase '^H' && read -p "Please enter the version number [format x.x.xx, as in 0.8.21 ] :" ct_new_ver
		[[ -z "${ct_new_ver}" ]] && echo "Cancel..." && exit 1
	else
		echo -e "${Info} Cloud Torrent latest version is ${ct_new_ver}"
	fi
}
check_ver_comparison(){
	ct_now_ver=$(${ct_file} --version)
	if [[ ${ct_now_ver} != ${ct_new_ver} ]]; then
		echo -e "${Info} There was a new version of Cloud Torrent [ ${ct_new_ver} ]"
		stty erase '^H' && read -p "Want to update ? [Y/n] :" yn
		[ -z "${yn}" ] && yn="y"
		if [[ ${yn} == [Yy] ]]; then
			check_pid
			[[ ! -z $PID ]] && kill -9 ${PID}
			rm -rf ${ct_file}
			Download_ct
			Start_ct
		fi
	else
		echo -e "${Info} Currently Cloud Torrent is the latest version [ ${ct_new_ver} ]" && exit 1
	fi
}
Download_ct(){
	cd ${file}
	if [[ ${bit} == "x86_64" ]]; then
		wget --no-check-certificate -O cloud-torrent.gz "https://github.com/jpillora/cloud-torrent/releases/download/${ct_new_ver}/cloud-torrent_linux_amd64.gz"
	else
		wget --no-check-certificate -O cloud-torrent.gz "https://github.com/jpillora/cloud-torrent/releases/download/${ct_new_ver}/cloud-torrent_linux_386.gz"
	fi
	[[ ! -e "cloud-torrent.gz" ]] && echo -e "${Error} Cloud Torrent fail to download !" && exit 1
	gzip -d cloud-torrent.gz
	[[ ! -e ${ct_file} ]] && echo -e "${Error} Deletion of Cloud Torrent failed (may be corrupted or Gzip not installed) !" && exit 1
	rm -rf cloud-torrent.gz
	chmod +x cloud-torrent
}
Service_ct(){
	if [[ ${release} = "centos" ]]; then
		if ! wget --no-check-certificate "https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/other/cloudt_centos" -O /etc/init.d/cloudt; then
			echo -e "${Error} Cloud Torrent service management script download failed !" && exit 1
		fi
		chmod +x /etc/init.d/cloudt
		chkconfig --add cloudt
		chkconfig cloudt on
	else
		if ! wget --no-check-certificate "https://raw.githubusercontent.com/aymjnd/cloudt/master/cloudt_debian" -O /etc/init.d/cloudt; then
			echo -e "${Error} Cloud Torrent service management script download failed !" && exit 1
		fi
		chmod +x /etc/init.d/cloudt
		update-rc.d -f cloudt defaults
	fi
	echo -e "${Info} Cloud Torrent service management script download completed !"
}
Installation_dependency(){
	gzip_ver=$(gzip -V)
	if [[ -z ${gzip_ver} ]]; then
		if [[ ${release} == "centos" ]]; then
			yum update
			yum install -y gzip
		else
			apt-get update
			apt-get install -y gzip
		fi
	fi
	mkdir ${file}
	mkdir ${dl_file}
}
Write_config(){
	cat > ${ct_conf}<<-EOF
host = ${ct_host}
port = ${ct_port}
user = ${ct_user}
passwd = ${ct_passwd}
title = ${ct_title}
EOF
}
Read_config(){
	[[ ! -e ${ct_conf} ]] && echo -e "${Error} Cloud Torrent Config file missing !" && exit 1
	host=`cat ${ct_conf}|grep "host = "|awk -F "host = " '{print $NF}'`
	port=`cat ${ct_conf}|grep "port = "|awk -F "port = " '{print $NF}'`
	user=`cat ${ct_conf}|grep "user = "|awk -F "user = " '{print $NF}'`
	passwd=`cat ${ct_conf}|grep "passwd = "|awk -F "passwd = " '{print $NF}'`
    title=`cat ${ct_conf}|grep "title = "|awk -F "title = " '{print $NF}'`
}
Set_host(){
	echo -e "Please input Cloud Torrent monitoring domain name or IP (when you want to bind the domain name, remember to do a good job of domain name resolution, currently only supports http:// access, do not write http:// write domain name!)"
	stty erase '^H' && read -p "(Default: 0.0.0.0 Monitor all IPs on the card):" ct_host
	[[ -z "${ct_host}" ]] && ct_host="0.0.0.0"
	echo && echo "========================"
	echo -e "	主机 : ${Red_background_prefix} ${ct_host} ${Font_color_suffix}"
	echo "========================" && echo
}
Set_port(){
	while true
		do
		echo -e "Please enter the Cloud Torrent listening port [1-65535] (if the domain is bound, then the proposed port 80)"
		stty erase '^H' && read -p "(Default port: 80):" ct_port
		[[ -z "${ct_port}" ]] && ct_port="80"
		expr ${ct_port} + 0 &>/dev/null
		if [[ $? -eq 0 ]]; then
			if [[ ${ct_port} -ge 1 ]] && [[ ${ct_port} -le 65535 ]]; then
				echo && echo "========================"
				echo -e "	Port : ${Red_background_prefix} ${ct_port} ${Font_color_suffix}"
				echo "========================" && echo
				break
			else
				echo "Please enter the correct port."
			fi
		else
			echo "Please enter the correct port."
		fi
	done
}
Set_user(){
	echo "Please enter your Cloud Torrent username"
	stty erase '^H' && read -p "(Default username: user):" ct_user
	[[ -z "${ct_user}" ]] && ct_user="user"
	echo && echo "========================"
	echo -e "	Username : ${Red_background_prefix} ${ct_user} ${Font_color_suffix}"
	echo "========================" && echo

	echo "Please enter your Cloud Torrent password"
	stty erase '^H' && read -p "(default password: doub.io):" ct_passwd
	[[ -z "${ct_passwd}" ]] && ct_passwd="doub.io"
	echo && echo "========================"
	echo -e "	Password : ${Red_background_prefix} ${ct_passwd} ${Font_color_suffix}"
	echo "========================" && echo
}
Set_title(){
	echo "Please enter your Cloud Torrent title"
	stty erase '^H' && read -p "(Default titl: alphaREKT):" ct_title
	[[ -z "${ct_title}" ]] && ct_title="alphaREKT"
	echo && echo "========================"
	echo -e "	Title : ${Red_background_prefix} ${ct_title} ${Font_color_suffix}"
	echo "========================" && echo
}
Set_conf(){
	Set_host
	Set_port
	stty erase '^H' && read -p "Do you want to set username and password ? [y/N] :" yn
	[[ -z "${yn}" ]] && yn="n"
	if [[ ${yn} == [Yy] ]]; then
		Set_user
	else
		ct_user="" && ct_passwd=""
	fi
}
Set_ct(){
	check_installed_status
	check_sys
	check_pid
    Set_title
	Set_conf
	Read_config
	Del_iptables
	Write_config
	Add_iptables
	Save_iptables
	Restart_ct
}
Install_ct(){
	[[ -e ${ct_file} ]] && echo -e "${Error} Cloud Torrent already installed !" && exit 1
	check_sys
	echo -e "${Info} Start setting user config ..."
	Set_conf
	echo -e "${Info} Start installing / configuring dependencies ..."
	Installation_dependency
	echo -e "${Info} Start testing the latest version ..."
	check_new_ver
	echo -e "${Info} Start downloading / installing ..."
	Download_ct
	echo -e "${Info} Start downloading / installing service scripts (init) ..."
	Service_ct
	echo -e "${Info} start writing to the config file ..."
	Write_config
	echo -e "${Info} Start setting up iptables firewall ..."
	Set_iptables
	echo -e "${Info} Start adding iptables firewall rules ..."
	Add_iptables
	echo -e "${Info} Start saving iptables firewall rules ..."
	Save_iptables
	echo -e "${Info} All the steps are installed, start up ..."
	Start_ct
}
Start_ct(){
	check_installed_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Error} Cloud Torrent running, please check !" && exit 1
	/etc/init.d/cloudt start
}
Stop_ct(){
	check_installed_status
	check_pid
	[[ -z ${PID} ]] && echo -e "${Error} Cloud Torrent not running, please check !" && exit 1
	/etc/init.d/cloudt stop
}
Restart_ct(){
	check_installed_status
	check_pid
	[[ ! -z ${PID} ]] && /etc/init.d/cloudt stop
	/etc/init.d/cloudt start
}
Log_ct(){
	[[ ! -e "${ct_log}" ]] && echo -e "${Error} Cloud Torrent log file does not exist !" && exit 1
	echo && echo -e "${Tip} Press ${Red_font_prefix} Ctrl + C ${Font_color_suffix} to stop viewing the log" && echo
	tail -f "${ct_log}"
}
Update_ct(){
	check_installed_status
	check_sys
	check_new_ver
	check_ver_comparison
	/etc/init.d/cloudt start
}
Uninstall_ct(){
	check_installed_status
	echo "Uninstall Cloud Torrent ? (y/N)"
	echo
	stty erase '^H' && read -p "(default: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_pid
		[[ ! -z $PID ]] && kill -9 ${PID}
		Read_config
		Del_iptables
		rm -rf ${file} && rm -rf /etc/init.d/cloudt
		if [[ ${release} = "centos" ]]; then
			chkconfig --del cloudt
		else
			update-rc.d -f cloudt remove
		fi
		echo && echo "Cloud torrent Uninstall completed !" && echo
	else
		echo && echo "Uninstall has been canceled..." && echo
	fi
}
View_ct(){
	check_installed_status
	Read_config
	if [[ "${host}" == "0.0.0.0" ]]; then
		host=$(wget -qO- -t1 -T2 ipinfo.io/ip)
		if [[ -z "${host}" ]]; then
			host=$(wget -qO- -t1 -T2 api.ip.sb/ip)
			if [[ -z "${host}" ]]; then
				host=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
				if [[ -z "${host}" ]]; then
					host="VPS_IP"
				fi
			fi
		fi
	fi
	if [[ "${port}" == "80" ]]; then
		port=""
	else
		port=":${port}"
	fi
	if [[ -z ${user} ]]; then
		clear && echo "————————————————" && echo
		echo -e " Your Cloud Torrent information :" && echo
		echo -e " Address\t: ${Green_font_prefix}http://${host}${port}${Font_color_suffix}"
        echo -e " Title\t: ${Green_font_prefix}${title}${Font_color_suffix}"
		echo && echo "————————————————"
	else
		clear && echo "————————————————" && echo
		echo -e " Your Cloud Torrent information :" && echo
		echo -e " Address\t: ${Green_font_prefix}http://${host}${port}${Font_color_suffix}"
		echo -e " Username\t: ${Green_font_prefix}${user}${Font_color_suffix}"
		echo -e " Password\t: ${Green_font_prefix}${passwd}${Font_color_suffix}"
        echo -e " Title\t: ${Green_font_prefix}${title}${Font_color_suffix}"
		echo && echo "————————————————"
	fi
}
Add_iptables(){
	iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${ct_port} -j ACCEPT
	iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${ct_port} -j ACCEPT
	iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${IncomingPort} -j ACCEPT
	iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${IncomingPort} -j ACCEPT
	iptables -I OUTPUT -m state --state NEW -m tcp -p tcp --dport ${IncomingPort} -j ACCEPT
	iptables -I OUTPUT -m state --state NEW -m udp -p udp --dport ${IncomingPort} -j ACCEPT
}
Del_iptables(){
	iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
	iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
	iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${IncomingPort} -j ACCEPT
	iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${IncomingPort} -j ACCEPT
	iptables -D OUTPUT -m state --state NEW -m tcp -p tcp --dport ${IncomingPort} -j ACCEPT
	iptables -D OUTPUT -m state --state NEW -m udp -p udp --dport ${IncomingPort} -j ACCEPT
}
Save_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
	else
		iptables-save > /etc/iptables.up.rules
	fi
}
Set_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		chkconfig --level 2345 iptables on
	else
		iptables-save > /etc/iptables.up.rules
		echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules' > /etc/network/if-pre-up.d/iptables
		chmod +x /etc/network/if-pre-up.d/iptables
	fi
}
echo && echo -e "Please enter a number to select the option

 ${Green_font_prefix}1.${Font_color_suffix} Install Cloud Torrent
 ${Green_font_prefix}2.${Font_color_suffix} Upgrade Cloud Torrent
 ${Green_font_prefix}3.${Font_color_suffix} Uninstall Cloud Torrent
————————————
 ${Green_font_prefix}4.${Font_color_suffix} Start Cloud Torrent
 ${Green_font_prefix}5.${Font_color_suffix} Stop Cloud Torrent
 ${Green_font_prefix}6.${Font_color_suffix} Restart Cloud Torrent
————————————
 ${Green_font_prefix}7.${Font_color_suffix} Set Cloud Torrent account
 ${Green_font_prefix}8.${Font_color_suffix} View Cloud Torrent account
 ${Green_font_prefix}9.${Font_color_suffix} View Cloud Torrent logs
————————————" && echo
if [[ -e ${ct_file} ]]; then
	check_pid
	if [[ ! -z "${PID}" ]]; then
		echo -e " Current status: ${Green_font_prefix}Installed${Font_color_suffix} and ${Green_font_prefix}Started${Font_color_suffix}"
	else
		echo -e " Current status: ${Green_font_prefix}Installed${Font_color_suffix} but ${Red_font_prefix}did not start${Font_color_suffix}"
	fi
else
	echo -e " Current status: ${Red_font_prefix}Not installed${Font_color_suffix}"
fi
echo
stty erase '^H' && read -p " Please enter number [1-9]:" num
case "$num" in
	1)
	Install_ct
	;;
	2)
	Update_ct
	;;
	3)
	Uninstall_ct
	;;
	4)
	Start_ct
	;;
	5)
	Stop_ct
	;;
	6)
	Restart_ct
	;;
	7)
	Set_ct
	;;
	8)
	View_ct
	;;
	9)
	Log_ct
	;;
	*)
	echo "Please enter the correct number [1-9]"
	;;
esac
