# ECK main cluster with Docker remote cluster for CCS and CCR

This lab starts:

- **Main cluster**: Elasticsearch and Kibana on ECK inside `k3d`.
- **Remote cluster**: Elasticsearch and Kibana in Docker Compose.

The ECK cluster is the local/main cluster. The Docker cluster is configured as the remote cluster alias `remote-docker`. The validation path proves both cross-cluster search (CCS) and cross-cluster replication (CCR).

## Prerequisites

Install:

- Docker with Docker Compose
- `k3d`
- `kubectl`
- `curl`
- `jq`
- `openssl`
- `nc`

Check the local machine:

```bash
make check
```

## Step-by-step setup

1. Create local config:

   ```bash
   cp .env.example .env
   ```

   Defaults:

   ```bash
   ES_VERSION=9.4.2
   ELASTIC_PASSWORD=changeme
   KIBANA_PASSWORD=changeme
   REMOTE_HTTP_PORT=9201
   REMOTE_TRANSPORT_PORT=9300
   REMOTE_CLUSTER_SERVER_PORT=9443
   REMOTE_KIBANA_PORT=5602
   ```

2. Preview the generated hostnames:

   ```bash
   make ingress-hosts
   ```

   The script detects the host IP and writes `runtime/runtime.env`. Example:

   ```text
   HOST_IP=10.0.10.130
   INGRESS_BASE_HOST=10-0-10-130.sslip.io
   ES_INGRESS_HOST=es.10-0-10-130.sslip.io
   KB_INGRESS_HOST=kb.10-0-10-130.sslip.io
   DOCKER_ES_HOST=remote-es.10-0-10-130.sslip.io
   DOCKER_KB_HOST=remote-kb.10-0-10-130.sslip.io
   REMOTE_RCS_HOST=remote-rcs.10-0-10-130.sslip.io
   REMOTE_TRANSPORT_HOST=remote-transport.10-0-10-130.sslip.io
   ```

3. Generate certificates:

   ```bash
   make certs
   ```

4. Start the recommended API-key setup:

   ```bash
   make up MODE=api-key
   ```

   `make up` creates a k3d cluster with Traefik disabled, maps `80` and `443` through the k3d load balancer, installs nginx ingress, deploys ECK, applies Elasticsearch/Kibana ingress resources, and starts the Docker remote services.

5. Print credentials and URLs:

   ```bash
   make credentials
   ```

6. Validate CCS and CCR:

   ```bash
   make test MODE=api-key
   ```

7. Tear down when finished:

   ```bash
   make down
   ```

## Credentials and URLs

Run:

```bash
make credentials
```

The helper prints:

- ECK Elasticsearch URL and `elastic` password from the ECK secret.
- ECK Kibana URL.
- Docker Elasticsearch URL and `.env` password.
- Docker Kibana URL.
- Docker Kibana backend `kibana_system` password.

Example endpoints:

```text
ECK Elasticsearch:     https://es.10-0-10-130.sslip.io
ECK Kibana:            https://kb.10-0-10-130.sslip.io
Docker Elasticsearch:  https://remote-es.10-0-10-130.sslip.io:9201
Docker Kibana:         http://remote-kb.10-0-10-130.sslip.io:5602
```

The `sslip.io` names resolve back to the detected host IP. The scripts also pass explicit `curl --resolve` values for validation so local DNS/proxy settings do not interfere.

## Ingress setup

The ingress setup follows the same pattern as the neighboring `eck-scale` sandbox:

- detect host IP with `ipconfig`, `ip route`, or `hostname -I`
- derive an `sslip.io` base domain from the IP, for example `10-0-10-130.sslip.io`
- create the k3d cluster with `--disable=traefik`
- expose k3d load balancer ports `80:80` and `443:443`
- install nginx ingress from `ingress-nginx/controller`
- create self-signed ingress TLS secrets for ECK Elasticsearch and Kibana
- apply `networking.k8s.io/v1` Ingress resources with `nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"`

Main ECK ingress hosts:

```text
ES_INGRESS_HOST=es.<host-ip-dashed>.sslip.io
KB_INGRESS_HOST=kb.<host-ip-dashed>.sslip.io
```

Docker hostnames use the same IP-derived base domain:

```text
DOCKER_ES_HOST=remote-es.<host-ip-dashed>.sslip.io
DOCKER_KB_HOST=remote-kb.<host-ip-dashed>.sslip.io
REMOTE_RCS_HOST=remote-rcs.<host-ip-dashed>.sslip.io
REMOTE_TRANSPORT_HOST=remote-transport.<host-ip-dashed>.sslip.io
```

If automatic IP detection picks the wrong interface, set `INGRESS_IP` before running `make up`:

```bash
INGRESS_IP=192.168.1.25 make up MODE=api-key
```

## Certificate setup

`make certs` runs `scripts/generate_certs.sh` and creates local development CAs and leaf certificates under `certs/`.

Generated CA files:

```text
certs/ca/remote-http-ca.crt
certs/ca/remote-http-ca.key
certs/ca/remote-rcs-ca.crt
certs/ca/remote-rcs-ca.key
certs/ca/remote-transport-ca.crt
certs/ca/remote-transport-ca.key
certs/ca/eck-transport-ca.crt
```

Generated leaf certificates:

```text
certs/remote-http/remote-http.crt
certs/remote-http/remote-http.key
certs/remote-rcs/remote-rcs.crt
certs/remote-rcs/remote-rcs.key
certs/remote-transport/remote-transport.crt
certs/remote-transport/remote-transport.key
```

The certificates include SANs for:

```text
localhost
127.0.0.1
host.k3d.internal
remote-http
remote-rcs
remote-transport
remote-es.<host-ip-dashed>.sslip.io
remote-rcs.<host-ip-dashed>.sslip.io
remote-transport.<host-ip-dashed>.sslip.io
<host-ip>
```

Certificate usage:

- `remote-http-ca`: signs the Docker Elasticsearch HTTP certificate. Local `curl` and Docker Kibana trust this CA.
- `remote-rcs-ca`: signs the Docker remote-cluster-server certificate used by API-key mode on `9443`. ECK mounts this CA through the `remote-rcs-ca` ConfigMap.
- `remote-transport-ca`: signs the Docker transport certificate used by legacy cert mode on `9300`. ECK trusts this CA through `spec.transport.tls.certificateAuthorities`.
- `eck-transport-ca`: extracted after ECK starts from `main-es-transport-certs-public`. In cert mode, this is appended to `certs/trusted-transport-ca.crt` so the Docker transport layer trusts ECK.
- `trusted-transport-ca.crt`: mounted into Docker Elasticsearch as its transport trust bundle.

These generated certs are for local development only. For production, use managed certificates and a rotation process for any copied CA material.

## Docker remote cluster configuration

Docker Elasticsearch is configured in `docker-compose.yml` with three TLS surfaces:

```yaml
xpack.security.http.ssl.enabled: "true"
xpack.security.http.ssl.certificate_authorities: certs/ca/remote-http-ca.crt
xpack.security.http.ssl.certificate: certs/remote-http/remote-http.crt
xpack.security.http.ssl.key: certs/remote-http/remote-http.key

xpack.security.transport.ssl.enabled: "true"
xpack.security.transport.ssl.verification_mode: certificate
xpack.security.transport.ssl.certificate_authorities: certs/trusted-transport-ca.crt
xpack.security.transport.ssl.certificate: certs/remote-transport/remote-transport.crt
xpack.security.transport.ssl.key: certs/remote-transport/remote-transport.key

remote_cluster_server.enabled: "true"
xpack.security.remote_cluster_server.ssl.enabled: "true"
xpack.security.remote_cluster_server.ssl.certificate_authorities: certs/ca/remote-rcs-ca.crt
xpack.security.remote_cluster_server.ssl.certificate: certs/remote-rcs/remote-rcs.crt
xpack.security.remote_cluster_server.ssl.key: certs/remote-rcs/remote-rcs.key
```

Published ports:

```text
9201 -> Elasticsearch HTTPS API
9300 -> legacy transport remote-cluster traffic
9443 -> API-key remote-cluster-server traffic
5602 -> Docker Kibana
```

Docker Kibana connects to Docker Elasticsearch as `https://remote-http:9200`. The Compose service gives Elasticsearch the `remote-http` network alias because the HTTP certificate is issued for `remote-http`, not the Docker service name `remote-es`.

From outside Docker, use the generated hostnames:

```text
https://remote-es.<host-ip-dashed>.sslip.io:9201
http://remote-kb.<host-ip-dashed>.sslip.io:5602
```

Docker Kibana uses the built-in `kibana_system` backend user. `make up` sets that user password from `.env`:

```http
POST /_security/user/kibana_system/_password
{
  "password": "<KIBANA_PASSWORD>"
}
```

## ECK main cluster configuration

The ECK Elasticsearch manifest is `manifests/eck-stack.yaml`.

Important node role:

```yaml
node.roles: ["master", "data_hot", "data_content", "ingest", "remote_cluster_client"]
```

The `remote_cluster_client` role is required for CCS and CCR requests from the main cluster.

API-key mode mounts the remote cluster server CA:

```yaml
xpack.security.remote_cluster_client.ssl.enabled: true
xpack.security.remote_cluster_client.ssl.certificate_authorities:
  - /usr/share/elasticsearch/config/remote-certs/remote-rcs-ca.crt
```

The CA is provided by:

```yaml
volumes:
  - name: remote-rcs-ca
    configMap:
      name: remote-rcs-ca
```

Cert mode trusts the Docker transport CA through:

```yaml
transport:
  tls:
    certificateAuthorities:
      configMapName: remote-transport-ca
```

The lab also applies `manifests/trial-license.yaml` so CCR and remote cluster features are available on ECK. The Docker remote starts its own trial through:

```http
POST /_license/start_trial?acknowledge=true
```

The ECK services are exposed through:

```text
manifests/elasticsearch-ingress.yaml
manifests/kibana-ingress.yaml
```

Kibana also receives:

```yaml
server.publicBaseUrl: "https://<KB_INGRESS_HOST>"
```

## API-key mode on port 9443

Run:

```bash
make up MODE=api-key
make test MODE=api-key
```

API-key mode is the recommended mode for Elasticsearch 8.14 and later.

Setup flow:

1. Docker Elasticsearch enables `remote_cluster_server.enabled: true`.
2. Docker exposes remote-cluster-server TLS on `9443`.
3. ECK trusts `remote-rcs-ca.crt`.
4. The script creates a cross-cluster API key on the Docker remote:

   ```http
   POST /_security/cross_cluster/api_key
   {
     "name": "eck-docker-ccs",
     "access": {
       "search": [
         { "names": [ "remote-products" ] }
       ],
       "replication": [
         { "names": [ "remote-leader" ] }
       ]
     }
   }
   ```

5. The encoded key is stored in ECK as a secure setting:

   ```text
   cluster.remote.remote-docker.credentials=<encoded cross-cluster API key>
   ```

6. The ECK Elasticsearch pod is restarted so the keystore setting is loaded.
7. The remote connection is configured from ECK:

   ```http
   PUT /_cluster/settings
   {
     "persistent": {
       "cluster": {
         "remote": {
           "remote-docker": {
             "mode": "proxy",
             "proxy_address": "remote-rcs.<host-ip-dashed>.sslip.io:9443",
             "server_name": "remote-rcs",
             "skip_unavailable": false
           }
         }
       }
     }
   }
   ```

Why `server_name` matters: ECK connects to the generated `remote-rcs.<host-ip-dashed>.sslip.io` endpoint, but the certificate identity used for SNI/verification is `remote-rcs`. The `server_name` setting makes the TLS handshake validate against that certificate identity.

## Legacy certificate mode on port 9300

Run:

```bash
make up MODE=cert
make test MODE=cert
```

Certificate authentication uses the Elasticsearch transport interface on `9300`. This model is deprecated in Elasticsearch 9.0 in favor of API-key authentication, but the lab includes it for legacy comparison.

Setup flow:

1. Docker transport TLS uses `remote-transport.crt`.
2. ECK trusts `remote-transport-ca.crt`.
3. After ECK starts, the script extracts ECK's transport CA:

   ```bash
   kubectl -n ccs-lab get secret main-es-transport-certs-public \
     -o go-template='{{index .data "ca.crt" | base64decode}}' \
     > certs/ca/eck-transport-ca.crt
   ```

4. The script appends the ECK CA into Docker's transport trust bundle:

   ```bash
   cat certs/ca/remote-transport-ca.crt certs/ca/eck-transport-ca.crt \
     > certs/trusted-transport-ca.crt
   ```

5. Docker Elasticsearch restarts so the expanded trust bundle is loaded.
6. The ECK remote connection is configured:

   ```http
   PUT /_cluster/settings
   {
     "persistent": {
       "cluster": {
         "remote": {
           "remote-docker": {
             "mode": "proxy",
             "proxy_address": "remote-transport.<host-ip-dashed>.sslip.io:9300",
             "server_name": "remote-transport",
             "skip_unavailable": false
           }
         }
       }
     }
   }
   ```

In this mode, connected clusters share a transport TLS security domain. Use it only when that trust model is acceptable.

## Validation details

`make test` performs the following checks:

1. Main and remote clusters are reachable.
2. `GET /_remote/info` reports `remote-docker.connected: true`.
3. ECK indexes `main-products/main-1`.
4. Docker indexes `remote-products/remote-1`.
5. ECK searches:

   ```http
   GET /main-products,remote-docker:remote-products/_search
   ```

6. Docker creates `remote-leader`.
7. ECK creates a CCR follower:

   ```http
   PUT /remote-leader-follower/_ccr/follow?wait_for_active_shards=1
   {
     "remote_cluster": "remote-docker",
     "leader_index": "remote-leader"
   }
   ```

8. A second remote leader document is indexed on Docker.
9. ECK confirms both leader documents appear in `remote-leader-follower`.

Expected output:

```text
CCS hits:
main-products	main-1	main	main-widget
remote-docker:remote-products	remote-1	remote	remote-widget
CCR follower count: 2
leader-1	1	first replicated remote leader document
leader-2	2	second replicated remote leader document
CCS and CCR validation passed
```

## Optional LLM connector and agent CCS data

`make llm` is intentionally separate from `make up`. It configures a Kibana LLM connector on the ECK/main Kibana instance and then loads larger sample data for cross-cluster agent search testing.

The target performs:

1. Verifies ECK Elasticsearch, ECK Kibana, Docker Elasticsearch, and `remote-docker` are reachable.
2. Creates or replaces the Kibana connector ID from `LLM_CONNECTOR_ID` with the selected provider settings.
3. Seeds at least 100 documents into the main cluster index `agent-main-knowledge`.
4. Seeds at least 100 different documents into the Docker remote index `agent-remote-knowledge`.
5. In API-key mode, refreshes the ECK secure setting for `cluster.remote.remote-docker.credentials` so the cross-cluster API key can search the new remote agent index.
6. Creates a Kibana data view named `CCS Agent Knowledge` targeting:

   ```text
   agent-main-knowledge,remote-docker:agent-remote-knowledge
   ```

7. Validates CCS from the main cluster:

   ```http
   GET /agent-main-knowledge,remote-docker:agent-remote-knowledge/_search
   ```

8. Executes the LLM connector once unless `LLM_VALIDATE=false`.

The script uses the Kibana Actions APIs documented by Elastic:

```http
POST /api/actions/connector/{id}
POST /api/actions/connector/{id}/_execute
```

Kibana API calls use the same ingress host format as the rest of this lab:

```text
https://kb.<host-ip-dashed>.sslip.io
```

### Ollama on the host

Ollama must expose an OpenAI-compatible chat completions endpoint from the host on port `11434`. The default URL is derived from the detected host IP:

```text
http://<HOST_IP>:11434/v1/chat/completions
```

Configure `.env`:

```bash
LLM_PROVIDER=ollama
OLLAMA_MODEL=
OLLAMA_API_KEY=ollama
LLM_DOC_COUNT=120
```

When `OLLAMA_MODEL` is empty, the script queries `http://<HOST_IP>:11434/api/tags` and uses the first installed model. Set `OLLAMA_MODEL` explicitly if you want a specific local model.

Run:

```bash
make llm
```

If your Ollama model or endpoint differs:

```bash
OLLAMA_MODEL=llama3.2 OLLAMA_API_URL=http://10.0.10.130:11434/v1/chat/completions make llm
```

### OpenAI

Configure `.env`:

```bash
LLM_PROVIDER=openai
OPENAI_API_KEY=<your-openai-api-key>
OPENAI_MODEL=gpt-4o-mini
OPENAI_API_URL=https://api.openai.com/v1/chat/completions
```

Run:

```bash
make llm
```

This creates a Kibana `.gen-ai` connector with `apiProvider: OpenAI`.

### Other OpenAI-compatible endpoint

Use this for compatible services that are not OpenAI, including proxied local models:

```bash
LLM_PROVIDER=openai-compatible
LLM_API_URL=https://your-compatible-endpoint/v1/chat/completions
LLM_API_KEY=<api-key-or-placeholder>
LLM_MODEL=<model-name>
make llm
```

This creates a Kibana `.gen-ai` connector with `apiProvider: Other`.

### Amazon Bedrock

Configure `.env`:

```bash
LLM_PROVIDER=bedrock
AWS_ACCESS_KEY_ID=<your-access-key-id>
AWS_SECRET_ACCESS_KEY=<your-secret-access-key>
AWS_REGION=us-east-1
BEDROCK_MODEL=us.anthropic.claude-sonnet-4-5-20250929-v1:0
BEDROCK_PROVIDER=anthropic
```

Lowercase `aws_access_key_id` and `aws_secret_access_key` are also accepted.

Run:

```bash
make llm
```

This creates an Elasticsearch Inference API endpoint on the main cluster:

```json
{
  "service": "amazonbedrock",
  "service_settings": {
    "access_key": "<AWS_ACCESS_KEY_ID>",
    "secret_key": "<AWS_SECRET_ACCESS_KEY>",
    "region": "<region>",
    "model": "<model>",
    "provider": "anthropic"
  }
}
```

The script validates the endpoint with:

```http
POST /_inference/chat_completion/ccs-lab-llm/_stream
{
  "messages": [
    { "role": "user", "content": "Reply with the words ccs llm ready." }
  ],
  "max_completion_tokens": 32
}
```

The older Kibana `.bedrock` connector uses a prompt-style Bedrock action and does not support newer Anthropic Messages API models such as Claude Sonnet 4.5. The Elasticsearch Inference API path is used here so current Bedrock chat-completion models work.

### LLM validation and UI checks

To create the connector and seed the agent-search documents without executing the LLM:

```bash
LLM_VALIDATE=false make llm
```

After `make llm` succeeds:

1. Open the ECK Kibana URL from `make credentials`.
2. For Ollama/OpenAI providers, go to **Stack Management > Connectors** and verify the `CCS Lab LLM` connector. For Bedrock, verify the main-cluster inference endpoint with `GET /_inference` and filter for `inference_id: ccs-lab-llm`.
3. Use the `CCS Agent Knowledge` data view or ES|QL/search tools to query both clusters.
4. Search for terms such as `remote-docker`, `main-eck`, `regional availability`, `service health`, or `cross cluster search agent testing`.

The expected CCS validation count is `LLM_DOC_COUNT * 2`. With the default `LLM_DOC_COUNT=120`, the validation query must return at least `240` hits across the main and remote indices.

### Remove the LLM setup

Run:

```bash
make llm-remove
```

The remove target deletes:

```text
Kibana connector: ccs-lab-llm
Bedrock inference endpoint: ccs-lab-llm
Kibana data view: ccs-agent-knowledge
Main index:        agent-main-knowledge
Remote index:      agent-remote-knowledge
```

It does not tear down the ECK or Docker clusters, and it does not remove the base CCS/CCR indices used by `make test`.

## Make targets

```bash
make check
make certs
make up MODE=api-key
make up MODE=cert
make test MODE=api-key
make test MODE=cert
make llm
make llm-remove
make credentials
make status
make logs
make down
make clean
```

## Troubleshooting

- `_remote/info` disconnected: run `make logs` and check TLS failures first.
- TLS SAN/server-name mismatch: ensure the remote setting uses `server_name: remote-rcs` for API-key mode and `server_name: remote-transport` for cert mode.
- CCR license error: verify the ECK trial license was applied and Docker accepted `POST /_license/start_trial?acknowledge=true`.
- ECK cannot reach Docker: verify `host.k3d.internal` resolves from inside the ECK pod and Docker publishes `9300` or `9443`.
- Cert mode unexpectedly uses API-key auth: recreate the lab with `make down && make up MODE=cert`; the secure setting `cluster.remote.<alias>.credentials` controls API-key mode.
