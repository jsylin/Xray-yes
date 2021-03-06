#!/usr/bin/env bash
# Github: https://github.com/jiuqi9997/Xray-yes
# Script link: https://github.com/jiuqi9997/Xray-yes/raw/main/xray-yes.sh
#
# Thanks for using.
#

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
stty erase ^?
script_version="1.1.60"
nginx_dir="/etc/nginx"
nginx_conf_dir="/etc/nginx/conf.d"
website_dir="/home/wwwroot"
xray_dir="/usr/local/etc/xray"
xray_log_dir="/var/log/xray"
xray_access_log="$xray_log_dir/access.log"
xray_error_log="$xray_log_dir/error.log"
xray_conf="/usr/local/etc/xray/config.json"
cert_dir="/usr/local/etc/xray"
info_file="$HOME/xray.inf"

check_root() {
	if [[ $EUID -ne 0 ]]; then
		error "无 root 权限，退出中"
	fi
}

color() {
	Green="\033[32m"
	Red="\033[31m"
	Yellow="\033[33m"
	GreenBG="\033[42;37m"
	RedBG="\033[41;37m"
	Font="\033[0m"
}

info() {
	echo "[*] $*"
}

error() {
	echo -e "${Red}[-]${Font} $*"
	exit 1
}

success() {
	echo -e "${Green}[+]${Font} $*"
}

warning() {
	echo -e "${Yellow}[*]${Font} $*"
}

panic() {
	echo -e "${RedBG}$*${Font}"
	exit 1
}

update_script() {
	fail=0
	ol_version=$(curl -sL github.com/jiuqi9997/Xray-yes/raw/main/xray-yes.sh | grep "script_version=" | head -1 | awk -F '=|"' '{print $3}')
	if [[ $(echo -e "$ol_version\n$script_version" | sort -rV | head -n 1) == "$ol_version" && "$ol_version" != "$script_version" ]]; then
		wget -O xray-yes.sh github.com/jiuqi9997/Xray-yes/raw/main/xray-yes.sh || fail=1
		[[ $fail -eq 1 ]] && warning "更新失败" && sleep 2 && return 0
		success "更新成功"
		sleep 2
		bash xray-yes.sh "$*"
		exit 0
	fi
}

install_all() {
	prepare_installation
	sleep 3
	check_env
	install_packages
	install_acme
	install_xray
	issue_certificate
	configure_xray
	xray_restart
	configure_nginx
	finish
	exit 0
}

prepare_installation() {
	get_info
	read -rp "请输入你的域名：" xray_domain
	[[ -z $xray_domain ]] && install_all
	echo ""
	echo "模式"
	echo ""
	echo "1. IPv4 only"
	echo "2. IPv6 only"
	echo "3. IPv4 & IPv6"
	echo ""
	read -rp "请输入数字（默认为 IPv4 only）：" ip_type
	[[ -z $ip_type ]] && ip_type=1
	if [[ $ip_type -eq 1 ]]; then
		domain_ip=$(ping -4 "$xray_domain" -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
		server_ip=$(curl -sL https://api64.ipify.org -4 || fail=1)
		[[ $fail -eq 1 ]] && error "本机 IP 地址获取失败"
		[[ "$server_ip" == "$domain_ip" ]] && success "域名已经解析到本机" && success=1
		if [[ $success -ne 1 ]]; then
			warning "域名没有解析到本机，证书申请可能失败"
			read -rp "继续？（yes/no）" choice
			case $choice in
			yes)
				;;
			y)
				;;
			no)
				exit 1
				;;
			n)
				exit 1
				;;
			*)
				exit 1
				;;
			esac
		fi
	elif [[ $ip_type -eq 2 ]]; then
		domain_ip=$(ping -6 "$xray_domain" -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
		server_ip=$(curl -sL https://api64.ipify.org -6 || fail=1)
		[[ $fail -eq 1 ]] && error "本机 IP 地址获取失败"
		[[ "$server_ip" == "$domain_ip" ]] && success "域名已经解析到本机" && success=1
		if [[ $success -ne 1 ]]; then
			warning "域名没有解析到本机，证书申请可能失败"
			read -rp "继续？（yes/no）" choice
			case $choice in
			yes)
				;;
			y)
				;;
			no)
				exit 1
				;;
			n)
				exit 1
				;;
			*)
				exit 1
				;;
			esac
		fi
	elif [[ $ip_type -eq 3 ]]; then
		domain_ip=$(ping -4 "$xray_domain" -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
		server_ip=$(curl -sL https://api64.ipify.org -4 || fail=1)
		[[ $fail -eq 1 ]] && error "本机 IPv4 地址获取失败"
		[[ "$server_ip" == "$domain_ip" ]] && success "域名已经解析到本机（IPv4）" && success=1
		if [[ $success -ne 1 ]]; then
			warning "域名没有解析到本机（IPv4），证书申请可能失败"
			read -rp "继续？（yes/no）" choice
			case $choice in
			yes)
				;;
			y)
				;;
			no)
				exit 1
				;;
			n)
				exit 1
				;;
			*)
				exit 1
				;;
			esac
		fi
		domain_ip6=$(ping -6 "$xray_domain" -c 1 | sed '1{s/[^(]*(//;s/).*//;q}')
		server_ip6=$(curl https://api64.ipify.org -6 || fail=1)
		[[ $fail -eq 1 ]] && error "本机 IPv6 地址获取失败"
		[[ "$server_ip" == "$domain_ip" ]] && success "域名已经解析到本机（IPv6）" && success=1
		if [[ $success -ne 1 ]]; then
			warning "域名没有解析到本机（IPv6），证书申请可能失败"
			read -rp "继续？（yes/no）" choice
			case $choice in
			yes)
				;;
			y)
				;;
			no)
				exit 1
				;;
			n)
				exit 1
				;;
			*)
				exit 1
				;;
			esac
		fi
	else
		error "请输入正确的数字"
	fi
	read -rp "请输入 xray 密码（默认使用 UUID）：" uuid
	read -rp "请输入 xray 端口（默认为 443）：" port
	[[ -z $port ]] && port=443
	[[ $port -gt 65535 ]] && echo "请输入正确的端口" && install_all
	configure_firewall
	nport=$(rand 10000 20000)
	nport1=$(expr $nport + 1)
	while ss -tnlp | grep -q ":$nport " || ss -tnlp | grep -q ":$nport1 "; do
		nport=$(rand 10000 20000)
		nport1=$(expr $nport + 1)
	done
	success "准备完成，即将开始安装"
}

get_info() {
	source /etc/os-release || source /usr/lib/os-release || panic "不支持此操作系统"
	if [[ $ID == "centos" ]]; then
		PM="yum"
		INS="yum install -y"
	elif [[ $ID == "debian" || $ID == "ubuntu" ]]; then
		PM="apt-get"
		INS="apt-get install -y"
	else
		error "不支持此操作系统"
	fi
}

configure_firewall() {
	fail=0
	if [[ $(type -P ufw) ]]; then
		if [[ $port -ne 443 ]]; then
			ufw allow $port/tcp || fail=1
			ufw allow $port/udp || fail=1
			success "开放 $port 端口成功"
		fi
		ufw allow 22,80,443/tcp || fail=1
		ufw allow 1024:65535/udp || fail=1
		yes|ufw enable || fail=1
		yes|ufw reload || fail=1
	elif [[ $(type -P firewalld) ]]; then
		systemctl start --now firewalld
		if [[ $port -ne 443 ]]; then
			firewall-offline-cmd --add-port=$port/tcp || fail=1
			firewall-offline-cmd --add-port=$port/udp || fail=1
			success "开放 $port 端口成功"
		fi
		firewall-offline-cmd --add-port=22/tcp --add-port=80/tcp --add-port=443/tcp || fail=1
		firewall-offline-cmd --add-port=1024-65535/udp || fail=1
		firewall-cmd --reload || fail=1
	else
		warning "请自行配置防火墙"
		return 0
	fi
	if [[ $fail -eq 1 ]]; then
		warning "防火墙配置失败，请手动配置"
	else
		success "防火墙配置成功"
	fi
}

rand() {
	min=$1
	max=$(($2-$min+1))
	num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')
	echo $(($num%$max+$min))
}

check_env() {
	if ss -tnlp | grep -q ":80 "; then
		error "80 端口被占用（需用于申请证书）"
	fi
	if [[ $port -eq "443" ]] && ss -tnlp | grep -q ":443 "; then
		error "443 端口被占用"
	elif ss -tnlp | grep -q ":$port "; then
		error "$port 端口被占用"
	fi
}

install_packages() {
	info "开始安装软件包"
	rpm_packages="tar zip unzip openssl lsof git jq socat nginx crontabs"
	apt_packages="tar zip unzip openssl lsof git jq socat nginx cron"
	if [[ $PM == "apt-get" ]]; then
		$PM update
		$INS wget curl gnupg2 ca-certificates dmidecode lsb-release
		update-ca-certificates
		echo "deb http://nginx.org/packages/$ID $(lsb_release -cs) nginx" | tee /etc/apt/sources.list.d/nginx.list
		curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
		$PM update
		$INS $apt_packages
	elif [[ $PM == "yum" || $PM == "dnf" ]]; then
		sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
		setenforce 0
		cat > /etc/yum.repos.d/nginx.repo <<EOF
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EOF
		$INS wget curl ca-certificates dmidecode epel-release
		update-ca-trust force-enable
		$INS $rpm_packages
	fi
	mkdir -p $nginx_dir
	cat > $nginx_dir/nginx.conf <<EOF
worker_processes  auto;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    tcp_nopush     on;

    keepalive_timeout  65;

    gzip  on;

    include $nginx_conf_dir/*.conf;
}
EOF
	systemctl enable nginx
	systemctl start nginx
	success "软件包安装完成"
}

install_acme() {
	info "开始安装 acme.sh"
	curl -L get.acme.sh | bash || error "acme.sh 安装失败，退出中"
	success "acme.sh 安装成功"
}

install_xray() {
	info "安装 Xray"
	curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh | bash -s - install
	ps aux | grep -q xray || error "Xray 安装失败"
	success "Xray 安装成功"
}

issue_certificate() {
	info "申请 SSL 证书"
	mkdir -p $nginx_conf_dir
	mkdir -p "$website_dir/$xray_domain"
	touch "$website_dir/$xray_domain/index.html"
	cat > "$nginx_conf_dir/default.conf" << EOF
server
{
	listen 80 default_server;
	listen [::]:80 default_server;

	return 444;

	access_log /dev/null;
	error_log /dev/null;
}
EOF
	cat > "$nginx_conf_dir/$xray_domain.conf" <<EOF
server
{
	listen 80;
	listen [::]:80;
	server_name $xray_domain;
	root $website_dir/$xray_domain;

	access_log /dev/null;
	error_log /dev/null;
}
EOF
	nginx -s reload
	/root/.acme.sh/acme.sh --issue -d "$xray_domain" --keylength ec-256 --fullchain-file $cert_dir/cert.pem --key-file $cert_dir/key.pem --webroot "$website_dir/$xray_domain" --renew-hook "systemctl restart xray" --force || error "证书申请失败"
	success "证书申请成功"
	generate_certificate
	chmod 600 $cert_dir/*.pem
	if id nobody | grep -q nogroup; then
		chown nobody:nogroup $cert_dir/*.pem
	else
		chown nobody:nobody $cert_dir/*.pem
	fi
}

generate_certificate() {
	info "生成自签名证书"
	openssl genrsa -out $cert_dir/self_signed_key.pem 2048
	openssl req -new -x509 -days 3650 -key $cert_dir/self_signed_key.pem -out $cert_dir/self_signed_cert.pem -subj "/CN=$server_ip"
	[[ ! -f $cert_dir/self_signed_cert.pem || ! -f $cert_dir/self_signed_key.pem ]] && error "生成自签名证书失败"
	success "生成自签名证书成功"
}

configure_xray() {
	[[ -z $uuid ]] && uuid=$(xray uuid)
	xray_flow="xtls-rprx-direct"
	cat > $xray_conf << EOF
{
    "log": {
        "access": "$xray_access_log",
        "error": "$xray_error_log",
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $port,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "flow": "$xray_flow"
                    }
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": $nport,
                        "xver": 1
                    },
                    {
                        "dest": $nport1,
                        "alpn": "h2",
                        "xver": 1
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "xtls",
                "xtlsSettings": {
                    "alpn": ["h2","http/1.1"],
                    "minVersion": "1.2",
                    "certificates": [
                        {
                            "certificateFile": "$cert_dir/self_signed_cert.pem",
                            "keyFile": "$cert_dir/self_signed_key.pem"
                        },
                        {
                            "certificateFile": "$cert_dir/cert.pem",
                            "keyFile": "$cert_dir/key.pem"
                        }
                    ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": ["http","tls"]
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF
}

xray_restart() {
	systemctl restart xray
	ps aux | grep -q xray || error "Xray 重启失败"
	success "Xray 重启成功"
	sleep 2
}

configure_nginx() {
	rm -rf "$website_dir/$xray_domain"
	mkdir -p "$website_dir/$xray_domain"
	wget -O web.tar.gz https://github.com/jiuqi9997/Xray-yes/raw/main/web.tar.gz
	tar xzvf web.tar.gz -C "$website_dir/$xray_domain"
	rm -rf web.tar.gz
	cat > "$nginx_conf_dir/$xray_domain.conf" <<EOF
server
{
	listen 80;
	listen [::]:80;
	server_name $xray_domain;
	return 301 https://\$http_host\$request_uri;

	access_log  /dev/null;
	error_log  /dev/null;
}

server
{
	listen $nport default_server;
	listen [::]:$nport default_server;
	listen $nport1 http2 default_server;
	listen [::]:$nport1 http2 default_server;

	return 444;

	access_log /dev/null;
	error_log /dev/null;
}

server
{
	listen $nport proxy_protocol;
	listen [::]:$nport proxy_protocol;
	listen $nport1 http2 proxy_protocol;
	listen [::]:$nport1 http2 proxy_protocol;
	server_name $xray_domain;
	index index.html;
	root $website_dir/$xray_domain;
	add_header Strict-Transport-Security "max-age=31536000" always;

	access_log  /dev/null;
	error_log  /dev/null;
}
EOF
	nginx -s reload
}

finish() {
	success "Xray 安装成功 (VLESS+tcp+xtls+nginx)"
	echo ""
	echo ""
	echo -e "$Green Xray 配置信息 $Font" | tee $info_file
	echo -e "$Green 地址 (address): $Font $server_ip " | tee -a $info_file
	echo -e "$Green 端口 (port): $Font $port " | tee -a $info_file
	echo -e "$Green 用户id (UUID/密码): $Font $uuid" | tee -a $info_file
	echo -e "$Green 流控 (flow): $Font $xray_flow" | tee -a $info_file
	echo -e "$Green SNI: $Font $xray_domain" | tee -a $info_file
	echo -e "$Green TLS: $Font ${RedBG}XTLS${Font}" | tee -a $info_file
	echo ""
	echo -e "$Green 分享链接:$Font vless://$uuid@$server_ip:$port?flow=xtls-rprx-direct&security=xtls&sni=$xray_domain#$xray_domain" | tee -a $info_file
	echo ""
	echo -e "${GreenBG} 提示：${Font}您可以在 Linux 平台上使用流控 ${RedBG}xtls-rprx-splice${Font} 以获得更好的性能。"
}

update_xray() {
	curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh | bash -s - install
	ps aux | grep -q xray || error "Xray 更新失败"
	success "Xray 更新成功"
}

uninstall_all() {
	get_info
	curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh | bash -s - remove --purge
	systemctl stop nginx
	if [[ $ID == "debian" || $ID == "ubuntu" ]]; then
		$PM purge -y nginx
	else
		$PM remove -y nginx
	fi
	rm -rf $nginx_dir
	rm -rf $website_dir
	rm -rf $info_file
	success "已卸载 Xray 和 nginx"
	exit 0
}

mod_uuid() {
	uuid_old=$(jq '.inbounds[].settings.clients[].id' $xray_conf || fail=1)
	[[ $(echo "$uuid_old" | jq '' | wc -l) -gt 1 ]] && error "有多个 UUID，请自行修改"
	uuid_old=$(echo "$uuid_old" | sed 's/\"//g')
	read -rp "请输入 Xray 密码（默认使用 UUID）：" uuid
	[[ -z $uuid ]] && uuid=$(xray uuid)
	sed -i "s/$uuid_old/$uuid/g" $xray_conf $info_file
	grep -q "$uuid" $xray_conf && success "UUID 修改成功" || error "UUID 修改失败"
	sleep 2
	xray_restart
	menu
}

mod_port() {
	port_old=$(jq '.inbounds[].port' $xray_conf || fail=1)
	[[ $(echo "$port_old" | jq '' | wc -l) -gt 1 ]] && error "有多个端口，请自行修改"
	read -rp "请输入 Xray 端口（默认为 443）：" port
	[[ -z $port ]] && port=443
	[[ $port -gt 65535 ]] && echo "请输入正确的端口" && mod_port
	[[ $port -ne 443 ]] && configure_firewall $port
	configure_firewall
	sed -i "s/$port_old/$port/g" $xray_conf $info_file
	grep -q $port $xray_conf && success "端口修改成功" || error "端口修改失败"
	sleep 2
	xray_restart
	menu
}

show_access_log() {
	[[ -f $xray_access_log ]] && tail -f $xray_access_log || panic "文件不存在"
}

show_error_log() {
	[[ -f $xray_error_log ]] && tail -f $xray_error_log || panic "文件不存在"
}

show_configuration() {
	[[ -f $info_file ]] && cat $info_file && exit 0
	panic "配置信息不存在"
}

switch_to_en() {
	wget -O xray-yes-en.sh https://github.com/jiuqi9997/Xray-yes/raw/main/xray-yes-en.sh
	echo "English version: xray-yes-en.sh"
	sleep 5
	bash xray-yes-en.sh
	exit 0
}

menu() {
	clear
	echo ""
	echo -e "  XRAY-YES - 安装管理 Xray $Red[$script_version]$Font"
	echo -e "  https://github.com/jiuqi9997/Xray-yes"
	echo ""
	echo -e " ---------------------------------------"
	echo -e "  ${Green}0.${Font} 升级 脚本"
	echo -e "  ${Green}1.${Font} 安装 Xray (VLESS+tcp+xtls+nginx)"
	echo -e "  ${Green}2.${Font} 升级 Xray core"
	echo -e "  ${Green}3.${Font} 卸载 Xray&nginx"
	echo -e " ---------------------------------------"
	echo -e "  ${Green}4.${Font} 修改 UUID"
	echo -e "  ${Green}5.${Font} 修改 端口"
	echo -e " ---------------------------------------"
	echo -e "  ${Green}6.${Font} 查看 实时访问日志"
	echo -e "  ${Green}7.${Font} 查看 实时错误日志"
	echo -e "  ${Green}8.${Font} 查看 Xray 配置信息"
	echo -e "  ${Green}9.${Font} 重启 Xray"
	echo -e " ---------------------------------------"
	echo -e "  ${Green}10.${Font} Switch to English"
	echo ""
	echo -e "  ${Green}11.${Font} 退出"
	echo ""
	read -rp "请输入数字：" choice
	case $choice in
	0)
		update_script
		;;
	1)
		install_all
		;;
	2)
		update_xray
		;;
	3)
		uninstall_all
		;;
	4)
		mod_uuid
		;;
	5)
		mod_port
		;;
	6)
		show_access_log
		;;
	7)
		show_error_log
		;;
	8)
		show_configuration
		;;
	9)
		xray_restart
		;;
	10)
		switch_to_en
		;;
	11)
		exit 0
		;;
	*)
		menu
		;;
	esac
}

main() {
	clear
	check_root
	color
	update_script "$*"
	case $1 in
	install)
		install_all
		;;
	update)
		update_xray
		;;
	remove)
		uninstall_all
		;;
	purge)
		uninstall_all
		;;
	uninstall)
		uninstall_all
		;;
	*)
		menu
		;;
	esac
}

main "$*"
