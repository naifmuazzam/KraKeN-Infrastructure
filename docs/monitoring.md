# KraKeN Infrastructure Monitoring

## Overview

KraKeN Infrastructure uses a layered monitoring architecture to observe the VPS host, Docker containers, application services, and infrastructure health.

The monitoring stack is designed around Prometheus for metrics collection and Grafana for visualization.

The monitoring architecture is intended to provide centralized visibility while keeping monitoring services isolated from public-facing services.

---

## Architecture

```text
                           KraKeN Infrastructure
                                   │
                                   ▼
                        ┌─────────────────────┐
                        │       Grafana       │
                        │ Visualization / UI  │
                        └──────────┬──────────┘
                                   │
                                   ▼
                        ┌─────────────────────┐
                        │     Prometheus      │
                        │ Metrics Collection  │
                        └──────┬────────┬─────┘
                               │        │
                  ┌────────────┘        └────────────┐
                  ▼                                  ▼
        ┌──────────────────┐              ┌──────────────────┐
        │  Node Exporter   │              │    cAdvisor      │
        │    VPS Metrics   │              │ Docker Metrics   │
        └──────────────────┘              └──────────────────┘
```

Future alerting architecture:

```text
                        ┌─────────────────┐
                        │    Prometheus   │
                        └────────┬────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │   Alertmanager  │
                        │ Alert Routing   │
                        └────────┬────────┘
                                 │
                                 ▼
                            ┌─────────┐
                            │ Telegram│
                            └─────────┘
```

---

## Monitoring Layers

The monitoring stack is divided into several layers.

### 1. VPS Host Monitoring

Node Exporter will provide operating-system-level metrics from the KraKeN VPS.

Initial metrics include:

* CPU utilization
* Memory utilization
* Load average
* Filesystem usage
* Disk I/O
* Network traffic
* System uptime
* Filesystem availability

The purpose of Node Exporter is to provide visibility into the underlying Ubuntu host independently from the Docker containers running on it.

Target:

```text
Ubuntu VPS
    │
    ▼
Node Exporter
    │
    ▼
Prometheus
```

### 2. Docker Monitoring

cAdvisor provides container-level resource metrics.

Initial metrics include:

* Container CPU usage
* Container memory usage
* Container network traffic
* Container disk I/O
* Container uptime
* Container resource consumption
* Container lifecycle information

The purpose of cAdvisor is to complement Node Exporter.

Node Exporter monitors the VPS host, while cAdvisor monitors the Docker container layer.

```text
Docker Engine
    │
    ├── Nexus-KraKeN
    ├── KraKeN Career
    ├── PostgreSQL
    ├── Prometheus
    ├── Grafana
    └── Other Services
            │
            ▼
        cAdvisor
            │
            ▼
        Prometheus
```

### 3. Application Monitoring

Application-specific monitoring will be introduced incrementally as services are deployed.

Potential monitoring targets include:

* Nexus-KraKeN
* KraKeN Career
* 9Router / AI Gateway
* PostgreSQL
* Reverse proxy
* WireGuard
* OpenVPN
* Backup services
* CI/CD services

Where possible, applications should provide reliable metrics endpoints or health endpoints.

If an application does not provide a reliable metrics or health interface, an artificial healthcheck should not be created simply to satisfy the monitoring architecture.

---

## Monitoring Components

### Prometheus

Prometheus is the central metrics collection and query engine.

Responsibilities:

* Scrape metrics from exporters
* Store time-series metrics
* Provide PromQL queries
* Provide metrics for Grafana
* Evaluate monitoring rules
* Provide the foundation for alerting

Initial Prometheus targets:

```text
Prometheus
├── Node Exporter
└── cAdvisor
```

Additional targets will be added as infrastructure services become available.

### Node Exporter

Node Exporter provides host-level operating system metrics.

Primary target:

```text
KraKeN VPS
```

Node Exporter should remain internal to the monitoring architecture and should not be exposed directly to the public Internet.

### cAdvisor

cAdvisor provides Docker container metrics.

Primary target:

```text
Docker Engine
```

cAdvisor requires access to relevant Docker runtime information and should therefore be treated as a privileged infrastructure monitoring component.

Its access should be limited to the minimum resources required for container monitoring.

### Grafana

Grafana provides visualization and dashboards for Prometheus metrics.

Initial dashboards should focus on:

#### VPS Overview

* CPU usage
* Memory usage
* Load
* Disk usage
* Network traffic
* Uptime

#### Docker Overview

* Container count
* Container CPU usage
* Container memory usage
* Container network traffic
* Container restart activity

#### Storage

* Filesystem usage
* Available storage
* Disk I/O
* Storage growth

#### Network

* Network receive traffic
* Network transmit traffic
* Interface activity
* Future VPN metrics

### Alertmanager

Alertmanager will provide centralized alert routing.

It will be introduced after the base Prometheus and Grafana stack is stable.

Responsibilities:

* Receive Prometheus alerts
* Group related alerts
* Deduplicate repeated alerts
* Route alerts to notification channels
* Control notification timing

Potential future notification channels include:

* Telegram
* Email
* Other operational notification systems

---

## Docker Network

Monitoring services will use the dedicated Docker network:

```text
kraken-monitoring
```

The monitoring network is separate from:

```text
kraken-proxy
kraken-internal
```

The intended architecture is:

```text
kraken-proxy
    │
    └── Public-facing / reverse-proxy services

kraken-internal
    │
    └── Application and database communication

kraken-monitoring
    │
    ├── Prometheus
    ├── Grafana
    ├── Node Exporter
    ├── cAdvisor
    └── Alertmanager
```

Monitoring services should only join additional Docker networks when there is a documented requirement.

---

## Network Isolation

Monitoring endpoints are infrastructure administration interfaces.

The following services should not be directly exposed to the public Internet by default:

* Prometheus
* cAdvisor
* Node Exporter
* Alertmanager

Grafana is also considered an administrative service.

Initial Grafana access should therefore be restricted to trusted administrative access.

Once the KraKeN OpenVPN environment is operational, VPN-based access is preferred.

Future public exposure, if ever required, must use explicit authentication, TLS, access control, and firewall policy.

---

## Access Model

The intended access model is:

```text
VPN / trusted admin access
          │
          ▼
       Grafana
          │
          ▼
     Prometheus
          │
     ┌────┴────┐
     ▼         ▼
Node Exporter cAdvisor
```

Monitoring components should not be reachable from arbitrary public Internet clients.

This reduces the attack surface of the infrastructure management layer.

---

## Healthchecks

Docker healthchecks and infrastructure monitoring serve different purposes.

### Docker Healthcheck

A Docker healthcheck determines whether an individual containerized service is operational.

Example:

```yaml
healthcheck:
  test: ["CMD", "..."]
  interval: 30s
  timeout: 5s
  retries: 3
  start_period: 10s
```

Healthchecks should test actual service availability rather than merely checking whether a process exists.

Examples:

* PostgreSQL → `pg_isready`
* Redis → `redis-cli ping`
* HTTP application → application health endpoint
* Prometheus → Prometheus health endpoint
* Grafana → Grafana health endpoint

If a reliable healthcheck is unavailable, no artificial healthcheck should be created.

### Monitoring

Prometheus-based monitoring provides broader infrastructure visibility.

```text
Docker healthcheck
    =
Individual container health

Prometheus monitoring
    =
Infrastructure-wide visibility
```

A container being reported as `healthy` does not mean the overall infrastructure is healthy.

---

## Restart Policy

Long-running production services should use:

```yaml
restart: unless-stopped
```

This provides automatic recovery after:

* Container crashes
* Docker daemon restarts
* VPS reboot

Manual service shutdown should remain respected.

One-shot jobs, initialization containers, migration jobs, and temporary debug containers should normally use:

```yaml
restart: "no"
```

Restart policy and healthcheck are separate mechanisms.

A container becoming `unhealthy` does not automatically mean Docker will restart it.

---

## Initial Metrics

The initial monitoring implementation will focus on the following metrics.

### CPU

* Host CPU utilization
* Container CPU utilization
* System load

### Memory

* Total memory
* Used memory
* Available memory
* Container memory consumption

### Storage

* Filesystem capacity
* Filesystem availability
* Disk I/O
* Container storage activity

### Network

* Interface receive traffic
* Interface transmit traffic
* Container network traffic
* Future VPN traffic

### Containers

* Running containers
* Container resource usage
* Container health
* Container restart activity

### System

* Host uptime
* Exporter availability
* Prometheus target availability
* Monitoring service availability

---

## Initial Alerts

Alerting will be introduced after the metrics and dashboards are validated.

Potential alerts include:

### Host Alerts

* High CPU utilization
* High memory utilization
* High filesystem usage
* Filesystem unavailable
* High disk I/O
* Host exporter unavailable

### Docker Alerts

* Container unavailable
* Container unhealthy
* Container repeatedly restarting
* Unexpected container resource consumption

### Monitoring Alerts

* Prometheus unavailable
* Prometheus target down
* Grafana unavailable
* Alertmanager unavailable

Thresholds will be defined after observing normal resource utilization on the VPS.

The initial alerting configuration should avoid overly aggressive thresholds that create unnecessary alert noise.

---

## Alerting Flow

The intended alerting flow is:

```text
Infrastructure
     │
     ▼
 Prometheus
     │
     ▼
 Alert Rules
     │
     ▼
Alertmanager
     │
     ▼
Notification Channel
```

Telegram integration will be added later.

Alert messages should provide enough information to identify:

* What failed
* Which service is affected
* When the alert started
* Severity
* Relevant metric or condition

---

## Initial Deployment Order

The monitoring stack will be deployed incrementally.

### Stage 1 — Prometheus

Deploy Prometheus and establish the central metrics collection layer.

### Stage 2 — Node Exporter

Add VPS host metrics.

### Stage 3 — cAdvisor

Add Docker container metrics.

### Stage 4 — Grafana

Deploy Grafana and connect it to Prometheus.

### Stage 5 — Dashboards

Create initial dashboards for:

* VPS
* Docker
* Storage
* Network

### Stage 6 — Alertmanager

Add centralized alert routing.

### Stage 7 — Telegram

Add Telegram notifications for selected operational alerts.

### Stage 8 — Additional Metrics

Add service-specific metrics as the KraKeN infrastructure expands.

---

## Future Monitoring Targets

As additional infrastructure is deployed, monitoring may be extended to:

```text
KraKeN VPS
├── Ubuntu
├── Docker
├── WireGuard
├── OpenVPN
├── Reverse Proxy
├── PostgreSQL
├── Nexus-KraKeN
├── KraKeN Career
├── 9Router / AI Gateway
├── Backup System
└── CI/CD
```

Remote Sigma infrastructure may be monitored only where explicitly permitted and where the required network connectivity and access controls are available.

Monitoring access between KraKeN and Sigma must follow the existing network segmentation and explicit allowlist policy.

---

## Hermes Integration

Hermes is intended to provide AI-assisted infrastructure analysis in the future.

Hermes should consume established monitoring data rather than replace the monitoring stack.

The intended architecture is:

```text
Infrastructure
      │
      ▼
Prometheus / Alertmanager
      │
      ▼
Monitoring Data
      │
      ▼
     Hermes
      │
      ├── Explain incidents
      ├── Summarize alerts
      ├── Identify patterns
      └── Assist troubleshooting
```

Hermes should not initially have unrestricted authority to modify production infrastructure.

Monitoring must remain functional without Hermes.

---

## Security Considerations

Monitoring infrastructure will follow the same security principles as the rest of KraKeN Infrastructure.

### Least Privilege

Monitoring components should receive only the access required for their specific monitoring function.

### Network Isolation

Monitoring services should use the dedicated:

```text
kraken-monitoring
```

network.

### No Unnecessary Public Exposure

Internal monitoring endpoints should remain private.

### Authentication

Administrative interfaces such as Grafana must use authentication.

### Secrets

Monitoring credentials, API tokens, and notification credentials must never be committed to the public Git repository.

Runtime secrets should be stored using the established KraKeN secrets strategy:

```text
/opt/kraken/secrets/
```

### Reproducibility

Monitoring configuration should remain version-controlled wherever it does not contain secrets.

---

## Backup and Data Considerations

Prometheus time-series data and Grafana configuration may require backup depending on the final persistence architecture.

Backup requirements will be defined together with the broader KraKeN backup and disaster recovery strategy.

Monitoring data should not be treated as a replacement for application or infrastructure backups.

---

## Resource Considerations

The KraKeN VPS currently provides:

* 2 CPU cores
* 7.5 GiB RAM
* 80 GiB SSD storage
* Ubuntu Server
* Docker Engine and Docker Compose

The monitoring stack must therefore be deployed with resource awareness.

Prometheus, Grafana, cAdvisor, and Node Exporter should be monitored after deployment to determine their actual resource consumption.

Resource limits should only be introduced after observing the workload and understanding the requirements of each service.

The monitoring stack itself must not consume an excessive proportion of the available VPS resources.

---

## Operational Principles

Monitoring should support infrastructure operations rather than become a source of unnecessary complexity.

The following operational principles apply:

1. Start with host and container monitoring.
2. Validate metrics before creating alerts.
3. Start with a small number of useful alerts.
4. Avoid alert fatigue.
5. Keep monitoring services isolated.
6. Keep monitoring configuration reproducible.
7. Keep secrets outside the public repository.
8. Monitor the monitoring stack itself.
9. Document significant monitoring changes.
10. Expand monitoring incrementally as infrastructure grows.

---

## Validation and Testing

Each monitoring component should be validated after deployment.

### Prometheus

Verify:

* Prometheus starts successfully.
* Prometheus can reach configured targets.
* Targets report the expected state.
* Metrics are being collected.
* PromQL queries return expected results.

### Node Exporter

Verify:

* Node Exporter starts successfully.
* Prometheus can scrape Node Exporter.
* Host CPU metrics are available.
* Host memory metrics are available.
* Filesystem metrics are available.
* Network metrics are available.

### cAdvisor

Verify:

* cAdvisor starts successfully.
* Prometheus can scrape cAdvisor.
* Running containers appear in the metrics.
* Container CPU metrics are available.
* Container memory metrics are available.
* Container network metrics are available.

### Grafana

Verify:

* Grafana starts successfully.
* Authentication is enabled.
* Prometheus is configured as the data source.
* Metrics can be queried.
* Dashboards display expected data.
* Grafana is not unnecessarily exposed to the public Internet.

### Alertmanager

Verify:

* Alertmanager starts successfully.
* Prometheus can communicate with Alertmanager.
* Test alerts are received.
* Alert grouping behaves as expected.
* Duplicate alerts are handled correctly.

### Telegram

When Telegram integration is implemented, verify:

* Test notifications are delivered.
* Alert messages contain useful context.
* Duplicate notifications are controlled.
* Credentials are stored outside Git.

---

## Troubleshooting Approach

Monitoring incidents should be investigated from the lowest layer upward.

Recommended troubleshooting order:

```text
VPS Host
   │
   ▼
Docker Engine
   │
   ▼
Monitoring Container
   │
   ▼
Monitoring Network
   │
   ▼
Prometheus Target
   │
   ▼
Grafana / Alertmanager
   │
   ▼
Notification Channel
```

For example, if Grafana shows no metrics:

1. Check whether Grafana is running.
2. Check whether Prometheus is running.
3. Check Prometheus target status.
4. Check exporter availability.
5. Check Docker network connectivity.
6. Check Prometheus configuration.
7. Check Grafana data-source configuration.
8. Check service logs.

This prevents higher-level symptoms from being mistaken for the root cause.

---

## Configuration Management

Monitoring configuration should follow the established KraKeN Infrastructure workflow:

```text
GitHub Design
      │
      ▼
Review
      │
      ▼
Commit
      │
      ▼
Push
      │
      ▼
VPS Deployment
      │
      ▼
Validation
```

Production configuration should not be created directly on the VPS
without first considering whether the configuration belongs in the
version-controlled repository.

Secrets remain excluded from Git.

---

## Current Repository Scope

The monitoring documentation belongs to the KraKeN Infrastructure
repository:

```text
KraKeN-Infrastructure/
├── compose/
├── config/
├── data/
├── secrets/
├── backups/
├── docs/
│   └── monitoring.md
├── scripts/
└── .github/
```

The actual runtime monitoring data and secrets remain outside the public
repository.

---

## Non-Goals

The initial monitoring phase does not attempt to:

* Build an AI operations platform immediately.
* Automatically modify production infrastructure.
* Automatically remediate every alert.
* Expose monitoring services publicly.
* Monitor every application before the applications exist.
* Replace Docker healthchecks with Prometheus.
* Replace backups with monitoring.
* Replace proper security controls with monitoring.
* Treat Grafana dashboards as a substitute for operational procedures.

These capabilities may be considered later when the underlying
infrastructure is stable.

---

## Design Principles

The monitoring architecture follows these principles:

1. Monitor the host and containers separately.
2. Prefer reliable service-level health checks.
3. Keep monitoring services isolated.
4. Do not expose internal monitoring endpoints publicly by default.
5. Use Prometheus as the central metrics layer.
6. Use Grafana for visualization.
7. Introduce alerting only after baseline metrics are stable.
8. Avoid excessive alert noise.
9. Add application-specific monitoring incrementally.
10. Keep monitoring configuration reproducible through Git.
11. Keep secrets outside the public repository.
12. Introduce AI-assisted monitoring only after conventional monitoring
    is stable.
13. Preserve human control over infrastructure changes.
14. Monitor the monitoring system itself.
15. Treat monitoring as an operational capability, not merely a dashboard.

---

## Phase 3 Roadmap

* [ ] Prometheus
* [ ] Node Exporter
* [ ] cAdvisor
* [ ] Grafana
* [ ] Basic dashboards
* [ ] Alertmanager
* [ ] Telegram notifications
* [ ] Application metrics
* [ ] VPN metrics
* [ ] Backup monitoring
* [ ] Hermes integration

---

## Current Status

Monitoring architecture has been designed and documented.

Implementation has not yet started.

The next implementation step is:

```text
Deploy Prometheus
```

All monitoring services must follow the established Docker network,
healthcheck, restart policy, environment, secrets, and security
strategies defined by KraKeN Infrastructure.

---

## Related Documentation

The monitoring architecture should be considered together with:

* `docs/architecture.md`
* `docs/network-design.md`
* `docs/security.md`
* `docs/deployment.md`
* `docs/services.md`
* `docs/troubleshooting.md`
* `docs/vpn.md`

These documents collectively define the broader KraKeN Infrastructure
architecture and operational approach.


