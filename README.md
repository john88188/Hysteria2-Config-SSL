# 获取免费SSL证书

这个项目其实是一个 Hysteria2 在 docker compose 运行的示例，但由于 `你懂的` 原因，`docker-compose.yml` 和 `hysteria.yaml` 我就不放出来了，可以自行到 [Hysteria2官网](https://v2.hysteria.network/zh/docs/getting-started/Installation/#docker)研究。

现在这个项目主要是提供了获取免费 SSL 证书的脚本，详细请参阅 [获取免费SSL证书的文档](get-cert-manual.md) 。 

## 注意事项

1. 需要给脚本 [get-cert.sh](get-cert.sh) 执行权限，即：`chmod +x get-cert.sh`。
2. 需要使用 root 权限执行，建议使用 root 登录再操作。
3. 获取证书前，请先将域名解析到服务器IP。
4. 获取证书后，只需要补充 `docker-compose.yml` 和 `hysteria.yaml` 就能跑（本项目不提供这两个文件）。
5. 证书有效期为 90 天，到期后需要手动更新证书。
6. 证书也可以用于建站，有了证书就可以使用 `https`。