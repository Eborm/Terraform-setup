# Terraform-setup (Proxmox)

A lightweight repository containing Terraform configuration and notes for managing Proxmox VMs with the bpg/proxmox provider.

This repo is intended as a personal toolkit and reference for provisioning QEMU VMs on a Proxmox cluster using Terraform. Detailed setup instructions and examples (including Talos/Kubernetes VM examples) live in Terraform.md — see that file for the full quick start and configuration steps.

## Highlights
- Provider configuration and variables for Proxmox
- A small `kubernetes/` module demonstrating how VMs are declared with Terraform
- Examples and notes in Terraform.md describing roles, ACLs, and recommended workflows

## Repository layout
- main.tf — top-level Terraform that configures the provider and loads modules
- variables.tf — variable definitions for sensitive credentials
- kubernetes/main.tf — module for Talos/Kubernetes VM definitions (example)
- Terraform.md — setup guide and quick start (detailed instructions)
- .terraform.lock.hcl — pinned provider hashes
- .gitignore — files and secrets to exclude from commits

## Quick pointer
Clone the repository and read Terraform.md for step-by-step setup, recommended ACLs, and examples:
- Terraform.md — the primary guide for provisioning and configuring VMs via Terraform in this repo

## Security note
Do not commit credentials or secret tfvars files. Use .gitignore and local overrides (e.g., secrets.auto.tfvars or environment variables) to keep sensitive data out of source control.

## Contributing
This repo is maintained as a personal reference. If you want to propose changes:
- Open an issue or pull request with a concise description of the change.
- Avoid committing any secrets or private data.
