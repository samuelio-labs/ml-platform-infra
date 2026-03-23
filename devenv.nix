{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  unstable = import inputs.nixpkgs-unstable { system = pkgs.stdenv.system; };
in
{
  # ── Packages ─────────────────────────────────────────────────────────────────

  packages = [
    # Infrastructure provisioning
    pkgs.terraform # IaC for cluster, namespaces, RBAC
    unstable.awscli2 # AWS CLI v2 — for EKS production target

    # Kubernetes
    pkgs.kubectl # K8s CLI
    pkgs.k9s # terminal cluster dashboard
    pkgs.k3d # local K8s cluster (mirrors EKS API surface)
    pkgs.kubernetes-helm # Helm — package manager for K8s manifests
    unstable.argocd # ArgoCD CLI — inspect / sync GitOps apps

    # Code quality
    pkgs.pre-commit # manage and run pre-commit hooks
    pkgs.tflint # Terraform linter
    pkgs.terraform-docs # auto-generate module variable/output docs
    pkgs.gitleaks # git secret scanning

    # Python tooling (model code, RAG services, pipeline SDK)
    pkgs.python3
    pkgs.uv # fast Python package manager / virtualenv

    # Developer experience
    pkgs.gh # GitHub CLI — PRs, issues, releases
    pkgs.jq # JSON querying (handy for K8s output)
    pkgs.yq-go # YAML querying
  ];

  # ── Environment variables ─────────────────────────────────────────────────────
  #
  # Override in devenv.local.nix (not committed) for personal settings.
  # env.AWS_PROFILE = "my-sso-profile";
  # env.KUBECONFIG = "${config.env.DEVENV_ROOT}/.kube/config";

  # ── Scripts ───────────────────────────────────────────────────────────────────

  scripts = {
    # Create the local k3d cluster with config matching production EKS topology.
    # Usage: cluster-up
    cluster-up.exec = ''
      set -euo pipefail
      CLUSTER_NAME="''${CLUSTER_NAME:-ml-platform}"

      if k3d cluster list | grep -q "^$CLUSTER_NAME"; then
        echo "Cluster '$CLUSTER_NAME' already exists — skipping creation."
        k3d cluster start "$CLUSTER_NAME" 2>/dev/null || true
      else
        echo "Creating k3d cluster: $CLUSTER_NAME"
        k3d cluster create "$CLUSTER_NAME" \
          --image rancher/k3s:v1.35.2-k3s1 \
          --agents 2 \
          --k3s-arg "--disable=traefik@server:0" \
          --port "8080:80@loadbalancer" \
          --port "8443:443@loadbalancer" \
          --wait
        echo "Cluster ready."
      fi

      k3d kubeconfig merge "$CLUSTER_NAME" --kubeconfig-merge-default
      kubectl config use-context "k3d-$CLUSTER_NAME"
      kubectl cluster-info
    '';

    # Destroy the local k3d cluster.
    # Usage: cluster-down
    cluster-down.exec = ''
      CLUSTER_NAME="''${CLUSTER_NAME:-ml-platform}"
      echo "Deleting k3d cluster: $CLUSTER_NAME"
      k3d cluster delete "$CLUSTER_NAME"
    '';

    # Bootstrap ArgoCD into the cluster and apply the App-of-Apps root application.
    # Run once after cluster-up. Expects KUBECONFIG to be set.
    # Usage: argocd-bootstrap
    argocd-bootstrap.exec = ''
      set -euo pipefail
      echo "Installing ArgoCD..."
      kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
      kubectl apply -n argocd \
        -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

      echo "Waiting for ArgoCD server to be ready..."
      kubectl rollout status deployment/argocd-server -n argocd --timeout=120s

      echo "Retrieving initial admin password..."
      ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
        -n argocd -o jsonpath="{.data.password}" | base64 -d)
      echo "ArgoCD admin password: $ARGOCD_PASSWORD"

      echo "Applying App-of-Apps..."
      kubectl apply -f argocd/app-of-apps.yaml

      echo ""
      echo "ArgoCD bootstrapped. Access the UI:"
      echo "  kubectl port-forward svc/argocd-server -n argocd 9090:80"
      echo "  open http://localhost:9090  (admin / $ARGOCD_PASSWORD)"
    '';

    # Run terraform plan for a given module.
    # Usage: tf-plan terraform/environments/local
    tf-plan.exec = ''
      set -euo pipefail
      DIR="''${1:?Usage: tf-plan <module-dir>}"
      echo "Planning: $DIR"
      terraform -chdir="$DIR" init -input=false
      terraform -chdir="$DIR" plan -no-color -out="$DIR/tfplan" 2>&1 | tee "$DIR/plan.txt"
    '';

    # Apply a previously generated plan.
    # Usage: tf-apply terraform/environments/local
    tf-apply.exec = ''
      set -euo pipefail
      DIR="''${1:?Usage: tf-apply <module-dir>}"
      echo "Applying: $DIR"
      terraform -chdir="$DIR" apply "$DIR/tfplan"
    '';

    # Tail logs for a platform component across all pods in a namespace.
    # Usage: mlogs mlplatform mlflow
    mlogs.exec = ''
      NS="''${1:?Usage: mlogs <namespace> <app-label>}"
      APP="''${2:?Usage: mlogs <namespace> <app-label>}"
      kubectl logs -n "$NS" -l "app=$APP" --all-containers --follow --max-log-requests=10
    '';
  };

  # ── Pre-commit hooks ──────────────────────────────────────────────────────────

  git-hooks.hooks = {
    # ── Terraform ──────────────────────────────────────────────────────────────

    terraform-format = {
      enable = true;
      name = "terraform-format";
      description = "Format all Terraform files with terraform fmt";
      entry = "${inputs.pre-commit-terraform}/hooks/terraform_fmt.sh";
      files = "\\.tf$";
      excludes = [ "\\.terraform-cache" ];
    };

    terraform-validate = {
      enable = true;
      name = "terraform-validate";
      description = "Validate Terraform configuration";
      entry = "${inputs.pre-commit-terraform}/hooks/terraform_validate.sh";
      files = "\\.tf$";
      excludes = [ "\\.terraform-cache" ];
    };

    terraform-lint = {
      enable = true;
      name = "terraform-lint";
      description = "Lint Terraform files with tflint";
      entry = "${inputs.pre-commit-terraform}/hooks/terraform_tflint.sh";
      files = "\\.tf$";
      excludes = [ "\\.terraform-cache" ];
    };

    terraform-doc = {
      enable = true;
      name = "terraform-doc";
      description = "Auto-generate variable/output docs into README.md";
      entry = "${inputs.pre-commit-terraform}/hooks/terraform_docs.sh";
      files = "\\.tf$";
      excludes = [ "\\.terraform-cache" ];
      args = [
        "--hook-config=--path-to-file=README.md"
        "--hook-config=--add-to-existing-file=true"
        "--hook-config=--create-file-if-not-exist=false"
      ];
    };

    # ── Security ───────────────────────────────────────────────────────────────

    detect-aws-credentials.enable = true;
    detect-private-keys.enable = true;
    ripsecrets.enable = true;

    gitleaks = {
      enable = true;
      name = "gitleaks";
      description = "Scan git history for accidentally committed secrets";
      entry = "${pkgs.gitleaks}/bin/gitleaks git -v";
      pass_filenames = false;
    };

    # ── General ────────────────────────────────────────────────────────────────

    check-json.enable = true;
    check-yaml.enable = true;
    check-merge-conflicts.enable = true;
    end-of-file-fixer.enable = true;
    trim-trailing-whitespace.enable = true;
    mixed-line-endings.enable = true;
    nixfmt.enable = true;
  };
}
