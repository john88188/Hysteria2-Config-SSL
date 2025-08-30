# Hysteria2 SSL证书获取手动指南

本指南提供了获取SSL证书的详细步骤，适用于无法使用自动脚本或需要手动操作的情况。

## 📋 前置要求

- ✅ 拥有一个真实域名（如：example.com）
- ✅ 域名能够解析到你的服务器IP
- ✅ 服务器能够访问互联网
- ✅ 具有root权限或sudo权限

## 🔧 步骤1：安装certbot

### Ubuntu/Debian系统
```bash
# 更新包列表
sudo apt update -y

# 安装certbot和相关工具
sudo apt install certbot python3-certbot-nginx curl -y
```

### CentOS/RHEL/Rocky/AlmaLinux系统
```bash
# 安装EPEL仓库
sudo yum install epel-release -y

# 安装certbot
sudo yum install certbot python3-certbot-nginx curl -y
```

### Fedora系统
```bash
# 安装certbot
sudo dnf install certbot python3-certbot-nginx curl -y
```

### Arch Linux系统
```bash
# 安装certbot
sudo pacman -Sy --noconfirm certbot certbot-nginx curl
```

## 🌐 步骤2：检查服务器IP

获取你的服务器公网IP地址：

```bash
# 方法1：使用ipinfo.io
curl -s https://ipinfo.io/ip

# 方法2：使用ipify.org
curl -s https://api.ipify.org

# 方法3：使用ifconfig.me
curl -s https://ifconfig.me
```

记录下显示的IP地址，例如：`123.456.789.012`

## 🔗 步骤3：配置域名DNS解析

登录你的域名管理面板（如：Cloudflare、阿里云、腾讯云等），添加A记录：

```
类型: A
名称: @ (或者你的子域名，如：hysteria)
值: 123.456.789.012 (你的服务器IP)
TTL: 自动或300秒
```

**等待DNS生效**（通常需要几分钟到几小时）

## ✅ 步骤4：验证DNS解析

检查域名是否正确解析到你的服务器：

```bash
# 使用ping检查
ping -c 4 your-domain.com

# 使用nslookup检查
nslookup your-domain.com

# 使用dig检查（如果已安装）
dig your-domain.com A
```

确保返回的IP地址与你的服务器IP一致。

## 🔐 步骤5：选择验证端口并获取SSL证书

### 检查端口占用情况

在获取证书前，先检查常用端口的占用情况：

```bash
# 检查端口占用
sudo netstat -tlnp | grep :80    # 检查80端口
sudo netstat -tlnp | grep :8080  # 检查8080端口
sudo netstat -tlnp | grep :8000  # 检查8000端口
sudo netstat -tlnp | grep :9000  # 检查9000端口

# 或使用ss命令
sudo ss -tlnp | grep :8080
```

### 方法1：使用80端口（标准HTTP端口）

```bash
# 如果有nginx或apache在运行，先停止
sudo systemctl stop nginx
sudo systemctl stop apache2

# 创建证书存储目录
mkdir -p ./acme

# 获取证书
sudo certbot certonly --standalone \
  --config-dir ./acme \
  --work-dir ./acme/work \
  --logs-dir ./acme/logs \
  -d your-domain.com
```

### 方法2：使用8080端口（推荐）

```bash
# 创建证书存储目录
mkdir -p ./acme

# 获取证书
sudo certbot certonly --standalone --http-01-port 8080 \
  --config-dir ./acme \
  --work-dir ./acme/work \
  --logs-dir ./acme/logs \
  -d your-domain.com
```

### 方法3：使用8000端口

```bash
# 创建证书存储目录
mkdir -p ./acme

# 获取证书
sudo certbot certonly --standalone --http-01-port 8000 \
  --config-dir ./acme \
  --work-dir ./acme/work \
  --logs-dir ./acme/logs \
  -d your-domain.com
```

### 方法4：使用9000端口

```bash
# 创建证书存储目录
mkdir -p ./acme

# 获取证书
sudo certbot certonly --standalone --http-01-port 9000 \
  --config-dir ./acme \
  --work-dir ./acme/work \
  --logs-dir ./acme/logs \
  -d your-domain.com
```

### 方法5：使用自定义端口

```bash
# 创建证书存储目录
mkdir -p ./acme

# 使用自定义端口（例如：3000）
sudo certbot certonly --standalone --http-01-port 3000 \
  --config-dir ./acme \
  --work-dir ./acme/work \
  --logs-dir ./acme/logs \
  -d your-domain.com
```

**重要提醒：**
- 选择的端口必须空闲且未被其他服务占用
- 防火墙必须允许所选端口的访问
- 所有方法都使用HTTP-01验证，需要域名正确解析到服务器IP

## 📁 步骤6：配置证书文件

证书获取成功后，创建软链接到Hysteria2期望的位置：

```bash
# 创建软链接
ln -sf ./acme/live/your-domain.com/fullchain.pem ./acme/cert.pem
ln -sf ./acme/live/your-domain.com/privkey.pem ./acme/privkey.pem

# 检查文件是否存在
ls -la ./acme/*.pem
```

应该看到类似输出：
```
lrwxrwxrwx 1 root root 45 date time cert.pem -> ./acme/live/your-domain.com/fullchain.pem
lrwxrwxrwx 1 root root 43 date time privkey.pem -> ./acme/live/your-domain.com/privkey.pem
```

## 🔄 步骤7：设置自动续期

Let's Encrypt证书有效期为90天，建议设置自动续期：

```bash
# 添加到crontab
sudo crontab -e

# 添加以下行（每月1号凌晨2点检查续期）
0 2 1 * * certbot renew --config-dir ./acme --work-dir ./acme/work --logs-dir ./acme/logs --quiet
```

## 🚀 步骤8：启动Hysteria2

现在可以启动Hysteria2服务了：

```bash
# 如果使用Docker
docker-compose up -d

# 如果直接运行
./hysteria server -c hysteria.yaml
```

## 🔍 故障排查

### 证书获取失败

**错误：域名解析失败**
```bash
# 检查DNS解析
nslookup your-domain.com
# 确保返回正确的IP地址
```

**错误：端口被占用**
```bash
# 检查端口占用（以8080为例）
sudo netstat -tlnp | grep 8080
# 或者
sudo ss -tlnp | grep 8080

# 停止占用端口的服务
sudo kill -9 <PID>

# 或选择其他空闲端口重新获取证书
```

**错误：防火墙阻止**
```bash
# Ubuntu/Debian - 开放端口（以8080为例）
sudo ufw allow 8080

# CentOS/RHEL - 开放端口
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload

# 注意：根据你选择的端口调整防火墙规则
```

**错误：权限不足**
```bash
# 确保以root权限运行
sudo su -
# 然后重新执行certbot命令
```

### 证书验证失败

**检查证书有效性**
```bash
# 检查证书信息
openssl x509 -in ./acme/cert.pem -text -noout

# 检查证书过期时间
openssl x509 -in ./acme/cert.pem -noout -dates
```

**测试HTTPS连接**
```bash
# 测试证书是否正常工作
openssl s_client -connect your-domain.com:443 -servername your-domain.com
```

## 📝 重要提醒

1. **域名必须真实有效** - 不能使用虚假域名
2. **DNS解析必须正确** - 域名必须解析到你的服务器IP
3. **防火墙配置** - 确保验证端口可以访问（根据你选择的端口）
4. **证书续期** - Let's Encrypt证书90天过期，记得续期
5. **备份证书** - 建议定期备份证书文件

## 🆘 获取帮助

如果遇到问题，可以：

1. 查看certbot日志：`sudo tail -f ./acme/logs/letsencrypt.log`
2. 检查Hysteria2日志
3. 参考Let's Encrypt官方文档：https://letsencrypt.org/docs/
4. 参考certbot官方文档：https://certbot.eff.org/docs/

---

**完成后，你的证书文件结构应该是：**
```
./acme/
├── cert.pem -> ./acme/live/your-domain.com/fullchain.pem
├── privkey.pem -> ./acme/live/your-domain.com/privkey.pem
└── live/
    └── your-domain.com/
        ├── fullchain.pem
        ├── privkey.pem
        ├── cert.pem
        └── chain.pem
```

现在可以启动Hysteria2服务了！🎉