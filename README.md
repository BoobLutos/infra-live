# infra-live

Live configuration for the Linode pilot. Each folder under `envs/` is one HCP Terraform workspace:

| Folder | Workspace | Applies |
| --- | --- | --- |
| `envs/dev/network` | `network-dev` | Automatically on merge |
| `envs/dev/app` | `app-dev` | Automatically, after `network-dev` applies |
| `envs/prod/network` | `network-prod` | After someone clicks **Confirm & apply** |
| `envs/prod/app` | `app-prod` | After `network-prod`, with confirmation |

## How a change flows

1. Branch, change files under `envs/...`, open a pull request.
2. GitHub Actions (`pr-checks`) runs `fmt`, `validate`, `tflint`, the OPA policy unit tests and a secret scan.
3. HCP Terraform runs a speculative plan for every workspace whose folder changed, evaluates the OPA policy set, and reports both as status checks on the PR.
4. Merge. Dev applies automatically; prod plans and waits for confirmation in HCP Terraform.

## Promoting a module version

Modules are pinned exactly (`version = "1.0.0"`). To roll out `1.1.0`, bump dev first in one PR, check it, then bump prod in a second PR.

## Layout

```
envs/<env>/<component>/   one root module per workspace
policies/                 OPA policy set loaded by HCP Terraform (5 policies, free-tier max)
policy-tests/             OPA unit tests (not loaded by HCP)
scripts/drift-check.sh    nightly plan-only runs via the HCP API
.github/workflows/        pr-checks.yml, drift-check.yml
```

## Local commands

```bash
terraform fmt -recursive
opa test policies policy-tests -v
# Speculative plan in HCP from your laptop (after `terraform login`):
cd envs/dev/app && terraform init && terraform plan
```

No credentials are stored in this repo. The Linode token reaches runs as the `LINODE_TOKEN` environment variable from the `linode-dev` / `linode-prod` variable sets.
