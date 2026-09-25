# Architecture

## Overview

KraKeN Infrastructure is a self-hosted infrastructure engineering environment built around a cloud VPS running Ubuntu Server.

The architecture is designed around network segmentation, secure remote access, container isolation, monitoring, and infrastructure automation.

The environment is divided into separate user-access networks and an infrastructure-to-infrastructure WireGuard tunnel.

## Core Architecture

```text
                              Internet
                                  │
                  ┌───────────────┴───────────────┐
                  │                               │
                  ▼                               ▼
         KraKeN OpenVPN                    Sigma OpenVPN
          10.2.0.0/24                       10.8.0.0/24
                  │                               │
                  ▼                               ▼
        ┌──────────────────┐             ┌──────────────────┐
        │    KraKeN VPS    │             │    Sigma Lab     │
        │                  │             │                  │
        │ Ubuntu Server    │             │ Internal Network │
        │ Docker           │             │ VPN Services     │
        │ UFW              │             │ Infrastructure   │
        │ WireGuard        │             │                  │
        └────────┬─────────┘             └────────┬─────────┘
                 │                                │
                 │         WireGuard              │
                 └─────── 10.200.0.0/30 ─────────┘
```

## VPN Architecture

### KraKeN OpenVPN

The KraKeN OpenVPN network uses `10.2.0.0/24`.

Its purpose is to provide authenticated access to services hosted within the KraKeN VPS environment.

Potential services include:

* 9Router
* Nexus-KraKeN
* KraKeN Career
* Monitoring interfaces
* Internal administration services

Access to Sigma is not granted automatically.

### Sigma OpenVPN

The Sigma environment uses the existing `10.8.0.0/24` OpenVPN network.

Its purpose is to provide authorized users with access to Sigma internal services.

The Sigma VPN is logically separated from the KraKeN VPS environment.

### WireGuard Backbone

The VPS and Sigma environments are connected through a dedicated WireGuard tunnel:

```text
VPS
10.200.0.1
    │
    │ WireGuard
    │
10.200.0.2
Sigma
```

The WireGuard network uses `10.200.0.0/30` as a point-to-point transit network.

WireGuard acts as an infrastructure backbone rather than a general user-access VPN.

## Network Security Boundaries

The architecture follows a default-deny and least-privilege approach.

```text
10.2.0.0/24
    │
    ├──► KraKeN VPS services
    │
    └──X──► Sigma

10.8.0.0/24
    │
    ├──► Sigma services
    │
    └──X──► KraKeN VPS

VPS
    │
    └──► Sigma
          via WireGuard
          explicit firewall/routing policy
```

A VPN connection does not automatically provide access to every network.

Cross-network communication must be explicitly permitted through routing and firewall policy.

## Docker Architecture

The KraKeN VPS uses Docker for modular service deployment.

Docker services are separated into dedicated networks according to their function.

```text
                         KraKeN VPS
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
   kraken-proxy        kraken-internal    kraken-monitoring
          │                   │                   │
          │                   │                   │
     Web/API layer      App/Database        Monitoring
          │              communication         stack
          │                   │                   │
     ┌────┼────┐         ┌────┼────┐       ┌────┼────┐
     │    │    │         │         │       │         │
   Nexus Career 9Router PostgreSQL  Apps Prometheus Grafana
```

Containers should only join the Docker networks required for their function.

### `kraken-proxy`

Used for services that need communication with the reverse proxy or HTTP(S) entry point.

Potential members include:

* Reverse proxy
* Nexus-KraKeN
* KraKeN Career
* 9Router

### `kraken-internal`

Used for internal application-to-application communication.

Potential members include:

* PostgreSQL
* Nexus-KraKeN
* KraKeN Career
* Internal application services

Database services should not be directly exposed to the public Internet.

### `kraken-monitoring`

Used for monitoring and observability services.

Potential members include:

* Prometheus
* Grafana
* Alertmanager
* cAdvisor
* Other monitoring components

## Security Layers

KraKeN Infrastructure applies multiple security layers.

### Host Access

* SSH public-key authentication using Ed25519
* Root SSH login disabled
* Password authentication disabled
* Keyboard-interactive authentication disabled
* UFW default-deny inbound policy

### Network Segmentation

* KraKeN OpenVPN separated from Sigma OpenVPN
* WireGuard used as the VPS-to-Sigma infrastructure tunnel
* Cross-network access controlled by firewall and routing policy

### Container Segmentation

* Dedicated Docker networks
* Internal services separated from proxy-facing services
* Database services not directly exposed

### Secrets Management

Sensitive credentials are excluded from the public Git repository.

Examples include:

* Private keys
* API keys
* Passwords
* Certificates
* Tokens
* Environment-specific credentials

## Service Architecture

The planned KraKeN service layer includes:

```text
KraKeN VPS
│
├── Reverse Proxy
│
├── 9Router
│
├── Nexus-KraKeN
│
├── KraKeN Career
│
├── Monitoring
│   ├── Prometheus
│   ├── Grafana
│   └── Alerting
│
└── Supporting Services
```

Services will be deployed incrementally and connected only to the Docker networks required by their role.

## Infrastructure Management

Infrastructure configuration is maintained through GitHub source control.

The repository is intended to contain:

* Documentation
* Example configurations
* Docker Compose definitions
* Infrastructure scripts
* Validation workflows
* Automation code

Secrets and private infrastructure credentials are intentionally excluded.

## Design Principles

The architecture follows these principles:

1. **Least privilege** — provide only the connectivity required.
2. **Network isolation** — separate environments into security zones.
3. **Explicit trust** — cross-network access must be intentionally permitted.
4. **Service isolation** — Docker containers should only share networks when required.
5. **Reproducibility** — infrastructure configuration should be documented and version controlled.
6. **Security by default** — unnecessary exposure should be avoided.
7. **Incremental deployment** — infrastructure is introduced and validated in controlled stages.

## Future Architecture

Planned infrastructure components include:

* Reverse proxy and HTTPS
* Monitoring and alerting
* KraKeN OpenVPN
* VPS-to-Sigma WireGuard connectivity
* Network segmentation and firewall policies
* 9Router AI gateway
* Nexus-KraKeN
* KraKeN Career
* Ansible infrastructure automation
* CI/CD validation
* Backup and disaster recovery
