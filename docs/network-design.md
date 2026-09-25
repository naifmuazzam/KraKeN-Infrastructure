# Network Design

## Overview

KraKeN Infrastructure uses separated VPN networks for administrative access, Sigma lab access, and infrastructure-to-infrastructure communication.

The design intentionally separates user access from the server-to-server tunnel so that connecting to one VPN does not automatically provide access to the other environment.

## Network Zones

### KraKeN OpenVPN

```text
Network: 10.2.0.0/24
Purpose: Administrative and personal access to KraKeN VPS services
```

The KraKeN OpenVPN network provides authenticated access to internal services hosted on the VPS.

Example services include:

* 9Router
* Nexus-KraKeN
* KraKeN Career
* Monitoring interfaces
* Internal administration services

Access to Sigma is not granted by default.

### Sigma OpenVPN

```text
Network: 10.8.0.0/24
Purpose: User and intern access to the Sigma internal lab
```

The Sigma OpenVPN network is dedicated to Sigma lab access.

Clients connected to this VPN can access authorized Sigma internal resources but do not receive automatic access to the KraKeN VPS environment.

### VPS ↔ Sigma WireGuard

```text
Network: 10.200.0.0/30
VPS:   10.200.0.1
Sigma: 10.200.0.2
Purpose: Infrastructure-to-infrastructure communication
```

WireGuard is used as the private backbone between the KraKeN VPS and the Sigma environment.

It is not intended to replace either OpenVPN network for normal user access.

## Routing Policy

The default routing policy follows network segmentation and least privilege.

| Source      | Destination         | Policy             |
| ----------- | ------------------- | ------------------ |
| 10.2.0.0/24 | KraKeN VPS services | Allowed            |
| 10.2.0.0/24 | Sigma network       | Denied by default  |
| 10.8.0.0/24 | Sigma network       | Allowed            |
| 10.8.0.0/24 | KraKeN VPS          | Denied by default  |
| VPS         | Sigma via WireGuard | Explicit allowlist |
| Sigma       | VPS via WireGuard   | Explicit allowlist |

Cross-network access must be explicitly enabled through routing and firewall rules when required.

## Security Principles

### Network Isolation

Each VPN represents a separate security zone.

A VPN connection provides connectivity only to the resources permitted by routing and firewall policy.

### Least Privilege

Services and networks should only receive the connectivity required for their function.

### Explicit Cross-Network Access

Communication between the VPS and Sigma environment must use the WireGuard tunnel and explicit firewall/routing rules.

### No Automatic Trust

Being connected to one VPN does not imply trust in another network.

## High-Level Topology

```text
                              Internet
                                  │
                 ┌────────────────┴────────────────┐
                 │                                 │
                 ▼                                 ▼
        KraKeN OpenVPN                       Sigma OpenVPN
         10.2.0.0/24                          10.8.0.0/24
                 │                                 │
                 ▼                                 ▼
        ┌─────────────────┐               ┌─────────────────┐
        │   KraKeN VPS    │               │   Sigma Lab     │
        │                 │               │                 │
        │ Docker Services │               │ Internal Lab    │
        │ 9Router         │               │ Wazuh           │
        │ Nexus           │               │ Grafana         │
        │ Career          │               │ DHCP/DNS         │
        │ Monitoring      │               │ PowerBI         │
        └────────┬────────┘               └────────┬────────┘
                 │                                 │
                 │         WireGuard               │
                 └──────── 10.200.0.0/30 ──────────┘
```

## Docker Network Segmentation

Docker services on the KraKeN VPS are further separated into dedicated Docker networks:

```text
kraken-proxy
    │
    └── Web-facing / reverse-proxy services

kraken-internal
    │
    └── Application and database communication

kraken-monitoring
    │
    └── Monitoring and observability services
```

Containers should only join the Docker networks required for their function.

## Future Changes

Network ranges and routing policies may evolve as additional services are introduced.

Any changes should be documented before implementation and reviewed against the existing security boundaries.
