#!/bin/bash

# Hysteria2 证书获取脚本
# 使用方法: ./get-cert.sh your-domain.com

DOMAIN=$1
ACME_DIR="./acme"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}使用方法: $0 <域名>${NC}"
    echo -e "${YELLOW}例如: $0 hysteria.example.com${NC}"
    exit 1
fi

echo -e "${GREEN}=== Hysteria2 SSL证书获取脚本 ===${NC}"
echo -e "${BLUE}域名: $DOMAIN${NC}"

# 检测Linux发行版
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/redhat-release ]; then
        OS="CentOS"
    else
        OS=$(uname -s)
    fi
}

# 安装certbot
install_certbot() {
    echo -e "${YELLOW}正在安装 certbot...${NC}"
    
    detect_os
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt update -y
        apt install certbot python3-certbot-nginx curl -y
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Rocky"* ]] || [[ "$OS" == *"AlmaLinux"* ]]; then
        yum update -y
        yum install epel-release -y
        yum install certbot python3-certbot-nginx curl -y
    elif [[ "$OS" == *"Fedora"* ]]; then
        dnf update -y
        dnf install certbot python3-certbot-nginx curl -y
    elif [[ "$OS" == *"Arch"* ]]; then
        pacman -Sy --noconfirm certbot certbot-nginx curl
    else
        echo -e "${RED}不支持的操作系统: $OS${NC}"
        echo -e "${YELLOW}请手动安装 certbot${NC}"
        exit 1
    fi
}

# 检查certbot是否安装
check_certbot() {
    if ! command -v certbot &> /dev/null; then
        echo -e "${YELLOW}未检测到 certbot，正在自动安装...${NC}"
        install_certbot
        
        if ! command -v certbot &> /dev/null; then
            echo -e "${RED}certbot 安装失败，请手动安装${NC}"
            exit 1
        fi
        echo -e "${GREEN}certbot 安装成功！${NC}"
    else
        echo -e "${GREEN}✓ certbot 已安装${NC}"
    fi
}

# 获取服务器公网IP
get_server_ip() {
    echo -e "${BLUE}正在获取服务器公网IP...${NC}"
    SERVER_IP=$(curl -s https://ipinfo.io/ip 2>/dev/null || curl -s https://api.ipify.org 2>/dev/null || curl -s https://ifconfig.me 2>/dev/null)
    
    if [ -z "$SERVER_IP" ]; then
        echo -e "${RED}无法获取服务器IP，请检查网络连接${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}服务器公网IP: $SERVER_IP${NC}"
}

# 检查域名解析
check_dns() {
    echo -e "${BLUE}正在检查域名解析...${NC}"
    
    # 使用ping检查域名解析
    RESOLVED_IP=$(ping -c 1 "$DOMAIN" 2>/dev/null | grep -oP '(?<=\()[0-9.]+(?=\))' | head -1)
    
    if [ -z "$RESOLVED_IP" ]; then
        echo -e "${RED}无法解析域名 $DOMAIN${NC}"
        echo -e "${YELLOW}请确保域名已正确配置DNS记录${NC}"
        return 1
    fi
    
    echo -e "${BLUE}域名解析IP: $RESOLVED_IP${NC}"
    
    if [ "$RESOLVED_IP" = "$SERVER_IP" ]; then
        echo -e "${GREEN}✓ 域名解析正确！${NC}"
        return 0
    else
        echo -e "${RED}✗ 域名解析不匹配${NC}"
        echo -e "${YELLOW}域名解析到: $RESOLVED_IP${NC}"
        echo -e "${YELLOW}服务器IP: $SERVER_IP${NC}"
        return 1
    fi
}

# 主程序开始
echo -e "${BLUE}步骤 1: 检查 certbot...${NC}"
check_certbot

echo -e "\n${BLUE}步骤 2: 获取服务器IP...${NC}"
get_server_ip

echo -e "\n${BLUE}步骤 3: DNS解析检查...${NC}"
echo -e "${YELLOW}请确保域名 $DOMAIN 的A记录已指向 $SERVER_IP${NC}"
echo -e "${YELLOW}按回车键继续检查域名解析...${NC}"
read -r

if ! check_dns; then
    echo -e "${RED}域名解析检查失败！${NC}"
    echo -e "${YELLOW}请先配置域名DNS记录，然后重新运行脚本${NC}"
    exit 1
fi

echo -e "\n${BLUE}步骤 4: 选择验证端口...${NC}"

# 检查端口占用情况
check_port() {
    local port=$1
    if netstat -tlnp 2>/dev/null | grep -q ":$port " || ss -tlnp 2>/dev/null | grep -q ":$port "; then
        return 1  # 端口被占用
    else
        return 0  # 端口空闲
    fi
}

# 显示常用端口状态
echo -e "${BLUE}检查常用端口状态：${NC}"
for port in 80 8080 8000 9000 3000; do
    if check_port $port; then
        echo -e "${GREEN}  端口 $port: 空闲 ✓${NC}"
    else
        echo -e "${RED}  端口 $port: 被占用 ✗${NC}"
    fi
done

echo ""
echo -e "${YELLOW}请选择证书验证方式：${NC}"
echo -e "${BLUE}1) 使用80端口 - 标准HTTP验证（推荐）${NC}"
echo -e "${BLUE}2) 使用端口转发 - 将80端口转发到其他端口${NC}"
echo -e "${BLUE}3) 使用DNS验证 - 无需开放任何端口${NC}"

while true; do
    echo -e "${YELLOW}请输入选择 (1-3): ${NC}"
    read -r choice
    
    case $choice in
        1)
            if check_port 80; then
                CERT_METHOD="standalone"
                CERT_PORT=80
                echo -e "${GREEN}将使用80端口进行验证${NC}"
                break
            else
                echo -e "${RED}80端口被占用！${NC}"
                echo -e "${YELLOW}请先停止占用80端口的服务，或选择其他验证方式${NC}"
                # 显示占用80端口的进程
                echo -e "${BLUE}占用80端口的进程：${NC}"
                netstat -tlnp 2>/dev/null | grep :80 || ss -tlnp 2>/dev/null | grep :80
            fi
            ;;
        2)
            echo -e "${BLUE}可用端口检查：${NC}"
            for port in 8080 8000 9000 3000; do
                if check_port $port; then
                    echo -e "${GREEN}  端口 $port: 空闲 ✓${NC}"
                else
                    echo -e "${RED}  端口 $port: 被占用 ✗${NC}"
                fi
            done
            
            while true; do
                echo -e "${YELLOW}请输入要使用的本地端口 (certbot将在此端口启动服务): ${NC}"
                read -r local_port
                if [[ "$local_port" =~ ^[0-9]+$ ]] && [ "$local_port" -ge 1024 ] && [ "$local_port" -le 65535 ]; then
                    if check_port $local_port; then
                        CERT_METHOD="port_forward"
                        CERT_PORT=$local_port
                        echo -e "${GREEN}将使用端口转发: 80 -> $local_port${NC}"
                        break 2
                    else
                        echo -e "${RED}端口 $local_port 被占用，请选择其他端口${NC}"
                    fi
                else
                    echo -e "${RED}请输入1024-65535之间的端口号${NC}"
                fi
            done
            ;;
        3)
            CERT_METHOD="dns"
            echo -e "${GREEN}将使用DNS验证${NC}"
            break
            ;;
        *)
            echo -e "${RED}无效选择，请输入1-3${NC}"
            ;;
    esac
done

echo -e "\n${BLUE}步骤 5: 获取SSL证书...${NC}"

# 检查并创建 acme 目录
if [ -d "$ACME_DIR" ]; then
    echo -e "${YELLOW}检测到已存在 acme 目录${NC}"
    if [ -f "$ACME_DIR/cert.pem" ] && [ -f "$ACME_DIR/privkey.pem" ]; then
        echo -e "${YELLOW}发现已存在的证书文件，是否要重新获取证书？ (y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}使用现有证书，脚本退出${NC}"
            exit 0
        fi
    fi
else
    echo -e "${BLUE}创建 acme 目录...${NC}"
    mkdir -p $ACME_DIR
fi

# 根据选择的方法获取证书
if [ "$CERT_METHOD" = "standalone" ]; then
    echo -e "${YELLOW}使用80端口获取证书...${NC}"
    certbot certonly --standalone \
      --config-dir $ACME_DIR \
      --work-dir $ACME_DIR/work \
      --logs-dir $ACME_DIR/logs \
      -d $DOMAIN

elif [ "$CERT_METHOD" = "port_forward" ]; then
    echo -e "${YELLOW}设置端口转发并获取证书...${NC}"
    echo -e "${BLUE}正在设置iptables规则: 80 -> $CERT_PORT${NC}"
    
    # 设置端口转发规则
    iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port $CERT_PORT
    
    echo -e "${YELLOW}在端口 $CERT_PORT 启动certbot...${NC}"
    certbot certonly --standalone --http-01-port $CERT_PORT \
      --config-dir $ACME_DIR \
      --work-dir $ACME_DIR/work \
      --logs-dir $ACME_DIR/logs \
      -d $DOMAIN
    
    # 获取证书后清理iptables规则
    echo -e "${BLUE}清理端口转发规则...${NC}"
    iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to-port $CERT_PORT 2>/dev/null

elif [ "$CERT_METHOD" = "dns" ]; then
    echo -e "${YELLOW}使用DNS验证获取证书...${NC}"
    echo -e "${BLUE}请按照提示添加DNS TXT记录${NC}"
    certbot certonly --manual --preferred-challenges dns \
      --config-dir $ACME_DIR \
      --work-dir $ACME_DIR/work \
      --logs-dir $ACME_DIR/logs \
      -d $DOMAIN
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}证书获取成功！${NC}"
    echo -e "${BLUE}证书位置: $ACME_DIR/live/$DOMAIN/${NC}"
    
    # 创建符号链接到 hysteria.yaml 期望的位置
    ln -sf $ACME_DIR/live/$DOMAIN/fullchain.pem $ACME_DIR/cert.pem
    ln -sf $ACME_DIR/live/$DOMAIN/privkey.pem $ACME_DIR/privkey.pem
    
    echo -e "${GREEN}已创建证书链接:${NC}"
    echo -e "${BLUE}  $ACME_DIR/cert.pem -> $ACME_DIR/live/$DOMAIN/fullchain.pem${NC}"
    echo -e "${BLUE}  $ACME_DIR/privkey.pem -> $ACME_DIR/live/$DOMAIN/privkey.pem${NC}"
    echo ""
    echo -e "${GREEN}🎉 现在可以启动 Hysteria2 服务了！${NC}"
else
    echo -e "${RED}证书获取失败，请检查：${NC}"
    echo -e "${YELLOW}1. 域名是否正确解析到此服务器${NC}"
    echo -e "${YELLOW}2. 防火墙是否允许80端口访问（Let's Encrypt只能通过80端口验证）${NC}"
    echo -e "${YELLOW}3. 是否以root权限运行${NC}"
    echo -e "${YELLOW}4. 如使用端口转发，检查iptables规则是否生效${NC}"
    echo -e "${YELLOW}5. 建议使用DNS验证避免端口问题${NC}"
fi