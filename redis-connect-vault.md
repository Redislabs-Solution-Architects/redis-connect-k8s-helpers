# Let's go!

## Quick install Vault in dev mode

```
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault hashicorp/vault \
    --set "server.dev.enabled=true"
```

## 
1. Create a k8s service account in your context K8s environment
```
kubectl create sa redis-connect
```

2. Enable the database secrets engine in Vault
```
vault secrets enable database
```
2b. Enable the kubernetes engine in Vault
```
vault secrets enable kubernetes
```
3. Configure K8s auth method in Vault
```
vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
```

4. Create a policy in Vault and link it to a database credential on a specific path
```
vault policy write redis-connect-policy - <<EOF
path "database/creds/redis-connect" {
  capabilities = ["read"]
}
EOF
```

5. Bind a service account in k8s to the role in Vault against the specific policy in a specific namespace
```
vault write auth/kubernetes/role/redis-connect \
    bound_service_account_names=redis-connect \
    bound_service_account_namespaces=redis-1 \
    policies=redis-connect-policy \
    ttl=24h
```

6. Create a database configuration in Vault using the `redis-connect` role with the `postgresql-database-plugin`. Replace `username`, `password` with a superuser for your postgres DB. Replace `<postgres_db_hostname>` with the actual hostname such that `connection_url` is a valid jdbcUrl.
```
vault write database/config/aws-postgres \
    plugin_name=postgresql-database-plugin \
    allowed_roles="redis-connect" \
    username="superuser" \
    password="123RedisVault" \
    connection_url="postgresql://{{username}}:{{password}}@<postgres_db_hostname>:5432/RedisConnect?sslmode=disable"
```

7. Create the database role in Vault
```
vault write database/roles/redis-connect \
    db_name=aws-postgres \
    creation_statements="CREATE ROLE \"{{name}}\" WITH REPLICATION LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
         GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; \
         ALTER USER \"{{name}}\" WITH SUPERUSER;" \
    default_ttl="5m" \
    max_ttl="5m"
```

8. Get a new credential from vault and/or revoke one.
```
vault read database/creds/redis-connect

Key                Value
---                -----
lease_id           database/creds/redis-connect/nTZrwR9YeJd8aMTrijPHc6aR
lease_duration     24h
lease_renewable    true
password           A1a-gQ7Y5uQJqStm03i0
username           v-token-redis-co-pA9IOheTgY1HJ24agfvf-1644346760

# revoke an existing credential lease based on the lease id:
vault lease revoke database/creds/redis-connect/nTZrwR9YeJd8aMTrijPHc6aR

All revocation operations queued successfully!
```

9. Annotate your pod with the following for those credentials to appear in your pod.

    ```
    spec:
    backoffLimit: 10 # try this many times before declaring failure
    template: # pod template
        metadata:
        labels:
            app: redis-connect-postgres-stage 
        annotations:
            vault.hashicorp.com/agent-inject: "true"
            vault.hashicorp.com/agent-pre-populate-only: "true"
            vault.hashicorp.com/role: "redis-connect"
            vault.hashicorp.com/secret-volume-path: "/vault/secrets"
            vault.hashicorp.com/agent-inject-file-redis-connect: "redisconnect_credentials_postgresql_RedisConnect-postgres"
            vault.hashicorp.com/agent-inject-secret-redis-connect: 'database/creds/redis-connect'
            vault.hashicorp.com/agent-inject-template-redis-connect: |
            {{ with secret "database/creds/redis-connect" -}}
            sourceUsername={{ .Data.username }}
            sourcePassword={{ .Data.password }}
            {{- end }}
    ```
10. Validate that those files exist in your pod filesystem.
```
$ kubectl exec -it redis-connect-postgres-746bd799f9-zgcbq -c redis-connect-postgres -- cat /vault/secrets/redisconnect_credentials_postgresql_RedisConnect-postgres
source.username=v-kubernet-redis-co-M13XXIRCo1uHeerPEHxt-1646241815
source.password=A1a-nKCHbeXqKJxa0LO8
```    
Or watch for transition events:
```
while true; do kubectl exec -it redis-connect-postgres-746bd799f9-zgcbq -c redis-connect-postgres -- cat /vault/secrets/redisconnect_credentials_postgresql_RedisConnect-postgres; sleep 30s; done
source.username=v-kubernet-redis-co-M13XXIRCo1uHeerPEHxt-1646241815
source.password=A1a-nKCHbeXqKJxa0LO8
...
```

# References
Thanks @Anton Umnikov for starting this [here](https://github.com/antonum/redis-connect-dist/blob/main/docs/vault.md).

https://www.hashicorp.com/blog/kubernetes-vault-integration-via-sidecar-agent-injector-vs-csi-provider
https://learn.hashicorp.com/tutorials/vault/kubernetes-openshift?in=vault/kubernetes
https://www.atlantbh.com/keeping-secrets-secure-with-vault-inside-a-kubernetes-cluster/
https://devopscube.com/vault-agent-injector-tutorial/

