# Let's go!

## Pre-reqs

- asd
- asd


1. Create a k8s service account in your context K8s environment
```
kubectl create sa redis-connect
```

1. Enable the database secrets engine in Vault
```
vault secrets enable database
```

1. Configure K8s auth method in Vault
```
vault write auth/kubernetes/config \
    token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443" \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
```

1. Create a policy in Vault and link it to a database credential on a specific path
```
vault policy write redis-connect-policy - <<EOF
path "database/creds/redis-connect" {
  capabilities = ["read"]
}
EOF
```

1. Bind a service account in k8s to the role in Vault against the specific policy in a specific namespace
```
vault write auth/kubernetes/role/redis-connect \
    bound_service_account_names=redis-connect \
    bound_service_account_namespaces=redis-1 \
    policies=redis-connect-policy \
    ttl=24h
```

1. Create a database configuration in Vault using the `redis-connect` role wit the `postgresql-database-plugin`.
```
vault write database/config/aws-postgres \
    plugin_name=postgresql-database-plugin \
    allowed_roles="redis-connect" \
    username="redisconnect" \
    password="Redis@123" \
    connection_url="postgresql://{{username}}:{{password}}@redis-connect.demo.redislabs.com:5432/RedisConnect?sslmode=disable"
```
# vault write database/roles/redis-connect \
#     db_name=aws-postgress \
#     creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
#         ALTER USER \"{{name}}\" WITH SUPERUSER;" \
#     default_ttl="5m" \
#     max_ttl="5m"


1. Create the database role in Vault
```
vault write database/roles/redis-connect \
    db_name=aws-postgres \
    creation_statements="CREATE ROLE \"{{name}}\" WITH REPLICATION LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
         GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; \
         ALTER USER \"{{name}}\" WITH SUPERUSER;" \
    default_ttl="5m" \
    max_ttl="5m"
```

1. Get a new credential from vault and/or revoke one.
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


# References

https://www.hashicorp.com/blog/kubernetes-vault-integration-via-sidecar-agent-injector-vs-csi-provider
https://learn.hashicorp.com/tutorials/vault/kubernetes-openshift?in=vault/kubernetes
https://www.atlantbh.com/keeping-secrets-secure-with-vault-inside-a-kubernetes-cluster/
https://devopscube.com/vault-agent-injector-tutorial/

