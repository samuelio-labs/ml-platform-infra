<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.14 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.5 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.1.1 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.7.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.argocd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [local_file.app_of_apps](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.apply_app_of_apps](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_chart_version"></a> [chart\_version](#input\_chart\_version) | ArgoCD Helm chart version | `string` | `"7.7.0"` | no |
| <a name="input_git_repo_url"></a> [git\_repo\_url](#input\_git\_repo\_url) | HTTPS URL of the ml-platform-infra git repository | `string` | n/a | yes |
| <a name="input_git_target_revision"></a> [git\_target\_revision](#input\_git\_target\_revision) | Branch or tag ArgoCD tracks | `string` | `"main"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_app_of_apps_path"></a> [app\_of\_apps\_path](#output\_app\_of\_apps\_path) | Path to the rendered App-of-Apps manifest |
| <a name="output_argocd_chart_version"></a> [argocd\_chart\_version](#output\_argocd\_chart\_version) | Installed ArgoCD Helm chart version |
| <a name="output_argocd_namespace"></a> [argocd\_namespace](#output\_argocd\_namespace) | Namespace where ArgoCD is installed |
<!-- END_TF_DOCS -->
