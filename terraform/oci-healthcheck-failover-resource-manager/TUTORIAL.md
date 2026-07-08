# Tutorial: failover automatico com OCI Health Checks, Alarm, Notifications e Function

Este guia monta a solucao completa:

```text
Health Check HTTP -> Monitoring Alarm -> Notifications Topic -> OCI Function -> START da VM standby
```

Use este tutorial em uma tenancy onde voce seja admin. Assim o Terraform consegue criar tambem o Dynamic Group e a Policy da Function.

## 1. Pre-requisitos

Voce precisa ter:

- Uma VM principal com endpoint HTTP de health check, por exemplo `http://IP/health-check`.
- Uma VM standby parada, que sera ligada quando o alarme disparar.
- Um compartment para criar Health Check, Alarm, Topic, Function e logs.
- Uma subnet para OCI Functions com saida para APIs OCI na porta 443.
- Permissao de admin para criar Dynamic Group e Policy.
- Cloud Shell ou uma maquina com Docker/Podman, OCI CLI e acesso ao OCIR.

Para Vinhedo:

```text
Region: sa-vinhedo-1
OCIR: vcp.ocir.io
```

## 2. Preparar a aplicacao monitorada

O endpoint ideal deve retornar:

```text
200 quando a aplicacao esta OK
400 ou 500 quando a aplicacao falhou
```

Teste:

```bash
curl -i http://<IP_DA_VM_PRINCIPAL>/health-check
```

Para o teste de failover, ele deve retornar `500`.

## 3. Descompactar o pacote v3 no Cloud Shell

Envie o zip v3 do projeto para o Cloud Shell, descompacte e entre no diretorio.

Use este arquivo:

```text
oci-healthcheck-failover-resource-manager-20260708-v3-no-schema.zip
```

O caminho por upload e o principal, porque em alguns ambientes o `git clone` pelo Cloud Shell pode ser bloqueado.

```bash
mkdir oci-healthcheck-failover-resource-manager
unzip oci-healthcheck-failover-resource-manager-20260708-v3-no-schema.zip -d oci-healthcheck-failover-resource-manager
cd oci-healthcheck-failover-resource-manager
```

Se voce ja estiver em um diretorio que contem `main.tf`, `variables.tf` e `function/`, pode seguir dali.

## 4. Descobrir o namespace e fazer login no OCIR

Pegue o namespace:

```bash
oci os ns get --query data --raw-output
```

Sempre que o tutorial mostrar `<namespace>`, substitua pelo valor retornado por esse comando.

Faca login no OCIR de Vinhedo:

```bash
docker login vcp.ocir.io
```

Use:

```text
Username: <namespace>/<seu_usuario_oci>
Password: Auth Token do OCI
```

## 5. Criar repositorio OCIR

No OCI Console:

```text
Developer Services > Containers & Artifacts > Container Registry
```

Crie o repositorio:

```text
failover/start-standby
```

Pode ser privado. Se for privado, mantenha `allow_faas_to_read_repos = true` no stack.

## 6. Build e push da imagem da Function

No Cloud Shell, dentro do diretorio do projeto:

Primeiro confira a arquitetura do Cloud Shell:

```bash
uname -m
```

Se retornar `aarch64`, use imagem ARM:

```bash
export PLATFORM=linux/arm64
export FUNCTION_IMAGE="vcp.ocir.io/<namespace>/failover/start-standby:1.0.0-arm64"
./scripts/build-and-push-function.sh
```

Nesse caso, no Resource Manager use:

```text
function_image = vcp.ocir.io/<namespace>/failover/start-standby:1.0.0-arm64
function_shape = GENERIC_ARM
```

Se retornar `x86_64`, use imagem x86:

```bash
export PLATFORM=linux/amd64
export FUNCTION_IMAGE="vcp.ocir.io/<namespace>/failover/start-standby:1.0.0"
./scripts/build-and-push-function.sh
```

Confirme no OCIR se a imagem apareceu como:

```text
failover/start-standby:1.0.0
```

ou, se voce usou ARM:

```text
failover/start-standby:1.0.0-arm64
```

## 7. Separar o zip para Resource Manager

Para o Resource Manager, use a versao v3 sem schema:

```text
oci-healthcheck-failover-resource-manager-20260708-v3-no-schema.zip
```

Se voce alterar arquivos do Terraform depois, pode gerar um novo pacote com:

```bash
./scripts/package-resource-manager.sh
```

Mas para este passo a passo, o pacote base esperado e:

```text
oci-healthcheck-failover-resource-manager-20260708-v3-no-schema.zip
```

## 8. Criar a Stack no Resource Manager

No OCI Console:

```text
Developer Services > Resource Manager > Stacks > Create stack
```

Selecione:

```text
My configuration
Upload zip file
```

Suba:

```text
oci-healthcheck-failover-resource-manager-20260708-v3-no-schema.zip
```

## 9. Variaveis principais da Stack

Preencha:

```text
region = sa-vinhedo-1
tenancy_ocid = <OCID_DA_TENANCY>
compartment_ocid = <OCID_DO_COMPARTMENT>
name_prefix = healthcheck-failover
```

VM standby:

```text
standby_instance_ocid = <OCID_DA_VM_STANDBY_PARADA>
```

Health Check:

```text
healthcheck_target = <IP_OU_HOST_SEM_HTTP_E_SEM_PATH>
healthcheck_path = /health-check
healthcheck_protocol = HTTP
healthcheck_port = 80
healthcheck_interval_in_seconds = 60
healthcheck_timeout_in_seconds = 10
```

Function:

```text
function_image = vcp.ocir.io/<namespace>/failover/start-standby:1.0.0
function_subnet_ocid = <OCID_DA_SUBNET_DA_FUNCTION>
function_memory_in_mbs = 256
function_timeout_in_seconds = 120
function_shape = GENERIC_X86
```

Se o build foi feito com `PLATFORM=linux/arm64`, use:

```text
function_image = vcp.ocir.io/<namespace>/failover/start-standby:1.0.0-arm64
function_shape = GENERIC_ARM
```

IAM:

```text
create_identity_resources = true
allow_faas_to_read_repos = true
dynamic_group_name = dg-healthcheck-failover-fn
policy_name = policy-healthcheck-failover-fn
```

Alarme:

```text
unhealthy_http_status_code_threshold = 400
alarm_pending_duration = PT1M
alarm_repeat_notification_duration = PT30M
alarm_severity = CRITICAL
alarm_query_override = vazio
```

Se a VM standby estiver em outro compartment, preencha:

```text
compute_compartment_ocid = <OCID_DO_COMPARTMENT_DA_VM_STANDBY>
```

## 10. Rodar Plan e Apply

Na Stack:

```text
Plan
Apply
```

Ao final, confira os outputs:

```text
http_monitor_id
alarm_id
alarm_query
notification_topic_id
function_application_id
function_id
function_subscription_id
dynamic_group_matching_rule
iam_policy_statements
```

## 11. Conferir recursos criados

Health Check:

```text
Observability & Management > Monitoring > Health Checks
```

Alarm:

```text
Observability & Management > Monitoring > Alarm Definitions
```

Topic:

```text
Developer Services > Application Integration > Notifications > Topics
```

Function:

```text
Developer Services > Functions > Applications
```

IAM:

```text
Identity & Security > Domains > Dynamic Groups
Identity & Security > Policies
```

## 12. Validar a configuracao do Alarm

O Terraform ja cria a query correta:

```text
HTTP.StatusCode[1m]{resourceId = "<http_monitor_id>"}.mean() >= 400
```

Se voce editar manualmente no Console, confira:

```text
Namespace: oci_healthchecks
Metric name: HTTP.StatusCode
Interval: 1 minute
Statistic: Mean
Metric dimension: resourceId = <http_monitor_id>
Trigger: greater than or equal to 400
Trigger delay: 1 minute
Message format: Raw messages
Topic: healthcheck-failover-topic
```

O item critico que nao pode faltar e:

```text
resourceId = <OCID_DO_HTTP_MONITOR>
```

Sem essa dimensao, o alarme pode ficar sem dados ou avaliar streams erradas.

## 13. Teste ponta a ponta

Deixe a VM standby parada.

Force o endpoint monitorado a retornar erro:

```bash
curl -i http://<IP_DA_VM_PRINCIPAL>/health-check
```

Resultado esperado:

```text
HTTP/1.0 500 Internal Server Error
```

Aguarde 1 a 3 minutos.

Confira o Alarm:

```text
Observability & Management > Monitoring > Alarm Status
```

Estado esperado:

```text
Firing
```

Confira a Function:

```text
Developer Services > Functions > Applications > healthcheck-failover-fn-app > Functions > healthcheck-failover-start-standby > Metrics
```

Esperado:

```text
Invocations > 0
Errors = 0
```

Confira a VM standby:

```text
Compute > Instances
```

Estado esperado:

```text
Starting ou Running
```

## 14. Logs da Function

Para ver logs:

```text
Observability & Management > Logging > Logs
```

Abra:

```text
healthcheck-failover-fn-app_invoke
```

Use a aba:

```text
Explore log
```

Buscas uteis:

```text
NotAuthorizedOrNotFound
FunctionInvokeExecutionFailed
instance_action
START
Standby instance
```

## 15. Troubleshooting

Alarme nao entra em Firing:

- Confirme se `/health-check` retorna `500`.
- Confirme se a metrica e `HTTP.StatusCode`.
- Confirme se a dimensao `resourceId` aponta para o OCID do HTTP Monitor.
- Confirme se o trigger e `>= 400`.

Function nao foi chamada:

- Confira o Topic do alarme.
- Confira a subscription `ORACLE_FUNCTIONS`.
- Confira se o Alarm usa `Send raw messages`.

Function foi chamada, mas deu erro `NotAuthorizedOrNotFound`:

- Falta IAM para a Function.
- Confira Dynamic Group:

```text
ALL {resource.type = 'fnfunc', resource.id = '<function_id>'}
```

- Confira Policy:

```text
Allow dynamic-group dg-healthcheck-failover-fn to manage instance-family in compartment id <compute_compartment_ocid>
```

Function nao consegue puxar imagem:

- Confira se a imagem existe no OCIR.
- Confira se `function_image` esta completo.
- Para repo privado, use:

```text
Allow service faas to read repos in tenancy
```

VM nao inicia mesmo sem erro:

- Confira se o OCID em `standby_instance_ocid` e da VM standby correta.
- Confira se a VM esta em `STOPPED`.
- Confira limites/capacidade da tenancy.

## 16. Voltar o ambiente ao normal

Depois do teste:

- Restaure o endpoint `/health-check` para retornar `200`.
- Aguarde o alarme voltar para `OK`.
- Se necessario, pare novamente a VM standby.
