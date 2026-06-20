# ORBI Sovereign Redis Cluster Setup (V1.2 Platinum)
## High-Availability 6-Node Configuration (TLS + ACLs)

This guide outlines the protocol for deploying a self-hosted Redis cluster to support the ORBI Sovereign Core.

### 1. Architecture Map
- **Nodes**: 6 (3 Masters, 3 Replicas)
- **Encryption**: TLS 1.3 with Client Certificate Authentication
- **Identity**: Granular ACLs (Access Control Lists)
- **Persistence**: AOF (Append Only File) + RDB Snapshots

---

### 2. Step 1: Generate TLS Certificates
On your designated Certificate Authority (CA) node:

```bash
# 1. Create Root CA
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -sha256 -key ca.key -days 3650 -out ca.crt

# 2. Generate Server Certificate for each node
openssl genrsa -out redis.key 2048
openssl req -new -sha256 -key redis.key -out redis.csr
openssl x509 -req -in redis.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out redis.crt -days 365
```

---

### 3. Step 2: Provision redis.conf
Use the hardened `redis.conf` provided in the root directory. Ensure you adjust the following parameters per node:
- `maxmemory`: Adjust based on host RAM (recommend 75% of total).
- `cluster-config-file`: Ensure unique paths if running multiple instances per host.

---

### 4. Step 3: Define ACL Policies
Create `/etc/redis/users.acl` to isolate functional domains:

```acl
# Disable default insecure user
user default off

# System Supervisor (Full Access)
user admin on >REPLACE_WITH_SHA256_HASH ~* +@all

# ORBI Application Node (Restricted to Finance Key-Space)
user orbi_node on >NODE_SECRET_HASH ~orbi:* +@read +@write +@pubsub -DEBUG -FLUSHALL
```

---

### 5. Step 4: Initialize Cluster
From a secure workstation with `redis-cli` installed:

```bash
redis-cli --tls \
  --cacert /etc/redis/tls/ca.crt \
  --cert /etc/redis/tls/redis.crt \
  --key /etc/redis/tls/redis.key \
  --cluster create \
  10.0.0.1:6379 10.0.0.2:6379 10.0.0.3:6379 \
  10.0.0.4:6379 10.0.0.5:6379 10.0.0.6:6379 \
  --cluster-replicas 1
```

---

### 6. Production Checklist (Post-Deployment)
- [ ] **Sentinel Check**: Run `redis-cli --tls CLUSTER INFO` to verify health.
- [ ] **Persistence Audit**: Verify `.aof` files are generating in the data volume.
- [ ] **Command Renaming**: Confirm `FLUSHALL` returns an error (use the new obfuscated name for maintenance).
- [ ] **DLP Verification**: Ensure no data is accessible without the Client CA certificate.

**ORBI Infrastructure Team**
*Classification: Institutional/Internal-Only*
