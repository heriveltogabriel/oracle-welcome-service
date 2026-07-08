# Oracle Welcome Service

Aplicação Python simples para validar VM Linux, Load Balancer, Instance Pool e autoscaling no OCI.

## O que ela faz

- Sobe uma página web "Bem-vindo Oracle".
- Escuta por padrão em `0.0.0.0:80`.
- Expõe health check em `/health-check`, `/health` e `/healthz`.
- Expõe health check de erro em `/health-check-error`, `/health-error` e `/healthz-error`.
- Instala serviço `systemd` chamado `oracle-welcome`.
- Roda com usuário dedicado, sem rodar a aplicação como root.

## Como instalar na VM Linux

Copie a pasta `oracle-welcome-service` para a VM e rode:

```bash
cd oracle-welcome-service
sudo bash install.sh
```

Teste local na VM:

```bash
curl http://127.0.0.1/health-check
curl -i http://127.0.0.1/health-check-error
curl http://127.0.0.1/
```

Resultados esperados:

```text
/health-check        -> HTTP 200, corpo OK
/health-check-error  -> HTTP 500, corpo ERROR
```

Ver status:

```bash
sudo systemctl status oracle-welcome --no-pager
```

Ver logs:

```bash
sudo journalctl -u oracle-welcome -f
```

Reiniciar:

```bash
sudo systemctl restart oracle-welcome
```

## Porta diferente

Se a porta 80 já estiver em uso:

```bash
sudo PORT=8080 bash install.sh
```

## Importante no OCI

Além do firewall da VM, libere a porta no NSG ou Security List da subnet.

Para Load Balancer, use:

```text
Backend port: 80
Health check path: /health-check
Health check protocol: HTTP
```

Para testar falha controlada no OCI Health Checks, aponte temporariamente o monitor para:

```text
Health check path: /health-check-error
```
