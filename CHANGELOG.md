# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-12-12

### Added

- **OpenTofu Migration**: Complete migration from Terraform to OpenTofu as the primary infrastructure-as-code tool
- **Configurable Credential Files**: New options to selectively create kubeconfig and talosconfig files locally
  - `create_kubeconfig_file`: Control whether to write kubeconfig to local file
  - `create_talosconfig_file`: Control whether to write talosconfig to local file
- **GitHub Actions Workflows**: Added CI/CD workflows for linting and validation

### Changed

- **IaC Tool**: Module now uses OpenTofu (>= 1.11.0) instead of Terraform
- **CI/CD**: Migrated CI/CD workflows from Terraform to OpenTofu
- **Documentation**: Updated README to reflect OpenTofu as the primary tool

### Fixed

- **Meta Values Conflict**: Resolved conflicts between meta values and count in configuration handling
- **Talos Configuration**: Fixed empty machine map for proper worker node configuration parsing
- **Output Generation**: Ensures outputs are generated only after cluster health validation to avoid certificate mismatches
- **Dependencies**: Added explicit `talos_machine_bootstrap` dependency to outputs for correct resource ordering

### Dependencies

- Updated GitHub Actions dependencies to latest versions
- Updated `hashicorp/local` provider to 2.6.1
- Updated `siderolabs/talos` provider to 0.9.0

## [0.1.0] - 2024-07-25

### Added

- Initial module release
- Automated Talos cluster bootstrapping from pre-provisioned nodes
- Support for multiple control plane and worker nodes
- Optional high availability with Virtual IP (VIP) for control plane
- Flexible networking with options to disable default CNI (Flannel) and kube-proxy
- Integrated metrics server support with certificate rotation
- Secure credential management with kubeconfig and talosconfig generation
- Health validation with configurable timeouts
- Support for external CNI solutions (e.g., Cilium)
- Option to allow workload scheduling on control plane nodes
- Configurable Kubernetes version support
- Comprehensive Talos cluster health checks

[Unreleased]: https://github.com/quiquecmtt/terraform-talos-cluster/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/quiquecmtt/terraform-talos-cluster/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/quiquecmtt/terraform-talos-cluster/releases/tag/v0.1.0
