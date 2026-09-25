# KraKeN Infrastructure

Self-hosted infrastructure lab for networking, Linux, security, containerization, VPN, and infrastructure automation.

## Overview

KraKeN Infrastructure is a personal infrastructure engineering lab designed to build and document practical experience across networking, Linux administration, security, containerization, VPN architecture, monitoring, and automation.

The environment is built around a cloud VPS running Ubuntu Server and is intended to evolve into a modular platform for self-hosted services and infrastructure experiments.

## Current Infrastructure

* Ubuntu Server 26.04
* SSH public-key authentication using Ed25519
* SSH hardening
* UFW host firewall
* Docker Engine
* Docker Compose
* WireGuard networking
* GitHub-based infrastructure source control

## Network Architecture

Planned network architecture:

```text
                         Internet
                            │
                            ▼
                  ┌──────────────────┐
                  │   KraKeN VPS     │
                  │   Ubuntu Server  │
                  │                  │
                  │   Docker         │
                  │   WireGuard      │
                  │   OpenVPN        │
                  │   Monitoring     │
                  └────────┬─────────┘
                           │
                     WireGuard
                           │
                           ▼
                  ┌──────────────────┐
                  │   Remote Lab     │
                  │                  │
                  │   Sigma Network  │
                  └──────────────────┘
```

Network segmentation and routing will be documented as the infrastructure evolves.

## Project Structure

```text
KraKeN-Infrastructure/
├── docker/
├── scripts/
├── config/
├── docs/
├── .github/
├── .gitignore
├── LICENSE
└── README.md
```

## Security

Security is treated as a core part of the infrastructure design.

Current security measures include:

* SSH public-key authentication
* Root SSH login disabled
* Password-based SSH authentication disabled
* Keyboard-interactive SSH authentication disabled
* UFW default-deny inbound policy
* Explicit firewall rules for required services
* Secrets and private keys excluded from version control

Sensitive deployment credentials, private keys, certificates, API tokens, and environment-specific secrets are intentionally not stored in this repository.

## Documentation

Documentation is maintained under [`docs/`](docs/).

Topics include:

* Architecture
* Deployment
* Network design
* VPN
* Security
* Services
* Troubleshooting

## Roadmap

* [x] VPS provisioning
* [x] SSH hardening
* [x] UFW firewall
* [x] Docker Engine and Compose
* [x] WireGuard VPS configuration
* [x] Docker service architecture
* [ ] Monitoring stack
* [ ] Reverse proxy and HTTPS
* [ ] KraKeN OpenVPN
* [ ] Remote lab WireGuard connectivity
* [ ] Network segmentation
* [ ] AI gateway
* [ ] Infrastructure automation with Ansible
* [ ] CI/CD and backup automation

## Disclaimer

This repository contains infrastructure configuration examples, documentation, and automation intended for learning, experimentation, and personal infrastructure engineering.

Configurations should be reviewed and adapted before being used in production environments.

## License

This project is licensed under the MIT License. See [`LICENSE`](LICENSE) for details.
