# Makefile for Terraform Streamlit ECS Infrastructure
# Provides convenient commands for common Terraform operations

# Default environment
ENV ?= dev

# Terraform variables
TF_VAR_FILE = environments/$(ENV).tfvars
BACKEND_CONFIG = environments/$(ENV).backend
PLAN_FILE = tfplan-$(ENV)

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
RED = \033[0;31m
NC = \033[0m # No Color

.PHONY: help init plan apply destroy validate format clean show output state-list state-show cost security docs

# Default target
help: ## Show this help message
	@echo "$(BLUE)Terraform Streamlit ECS Infrastructure$(NC)"
	@echo "====================================="
	@echo ""
	@echo "$(GREEN)Usage:$(NC) make <target> [ENV=<environment>]"
	@echo ""
	@echo "$(GREEN)Environments:$(NC) dev, staging, prod"
	@echo "$(GREEN)Default Environment:$(NC) $(ENV)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform with backend configuration
	@echo "$(BLUE)Initializing Terraform for $(ENV) environment...$(NC)"
	@terraform init -backend-config=$(BACKEND_CONFIG) -upgrade

validate: ## Validate Terraform configuration
	@echo "$(BLUE)Validating Terraform configuration...$(NC)"
	@./validate.sh -e $(ENV)

format: ## Format Terraform code
	@echo "$(BLUE)Formatting Terraform code...$(NC)"
	@terraform fmt -recursive .

format-check: ## Check if Terraform code is formatted
	@echo "$(BLUE)Checking Terraform code formatting...$(NC)"
	@terraform fmt -check -diff -recursive .

plan: init ## Create Terraform execution plan
	@echo "$(BLUE)Creating execution plan for $(ENV) environment...$(NC)"
	@terraform plan -var-file=$(TF_VAR_FILE) -out=$(PLAN_FILE)

plan-detailed: init ## Create detailed Terraform execution plan
	@echo "$(BLUE)Creating detailed execution plan for $(ENV) environment...$(NC)"
	@terraform plan -var-file=$(TF_VAR_FILE) -detailed-exitcode

plan-destroy: init ## Create destruction plan
	@echo "$(YELLOW)Creating destruction plan for $(ENV) environment...$(NC)"
	@terraform plan -destroy -var-file=$(TF_VAR_FILE) -out=$(PLAN_FILE)-destroy

apply: plan ## Apply Terraform changes
	@echo "$(GREEN)Applying changes to $(ENV) environment...$(NC)"
	@terraform apply $(PLAN_FILE)
	@rm -f $(PLAN_FILE)

apply-auto: init ## Apply Terraform changes without confirmation
	@echo "$(GREEN)Auto-applying changes to $(ENV) environment...$(NC)"
	@terraform apply -auto-approve -var-file=$(TF_VAR_FILE)

destroy: plan-destroy ## Destroy infrastructure
	@echo "$(RED)Destroying $(ENV) environment infrastructure...$(NC)"
	@echo "$(RED)WARNING: This will permanently delete resources!$(NC)"
	@read -p "Are you sure? Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ] || exit 1
	@terraform apply $(PLAN_FILE)-destroy
	@rm -f $(PLAN_FILE)-destroy

destroy-auto: init ## Destroy infrastructure without confirmation
	@echo "$(RED)Auto-destroying $(ENV) environment infrastructure...$(NC)"
	@terraform destroy -auto-approve -var-file=$(TF_VAR_FILE)

show: ## Show the current state or plan
	@if [ -f "$(PLAN_FILE)" ]; then \
		echo "$(BLUE)Showing execution plan for $(ENV) environment...$(NC)"; \
		terraform show $(PLAN_FILE); \
	else \
		echo "$(BLUE)Showing current state for $(ENV) environment...$(NC)"; \
		terraform show; \
	fi

output: ## Show Terraform outputs
	@echo "$(BLUE)Terraform outputs for $(ENV) environment:$(NC)"
	@terraform output -json | jq '.'

output-summary: ## Show key Terraform outputs in table format
	@echo "$(BLUE)Key outputs for $(ENV) environment:$(NC)"
	@terraform output -json | jq -r '
		"| Output | Value |",
		"|--------|-------|",
		(.load_balancer_dns // empty | "| Load Balancer DNS | \(.) |"),
		(.streamlit_app_url // empty | "| Application URL | \(.) |"),
		(.ecr_repository_uri // empty | "| ECR Repository | \(.) |"),
		(.ecs_cluster_name // empty | "| ECS Cluster | \(.) |"),
		(.ecs_service_name // empty | "| ECS Service | \(.) |")
	'

state-list: ## List all resources in Terraform state
	@echo "$(BLUE)Resources in $(ENV) environment state:$(NC)"
	@terraform state list

state-show: ## Show details of a specific resource (usage: make state-show RESOURCE=<resource>)
	@if [ -z "$(RESOURCE)" ]; then \
		echo "$(RED)Usage: make state-show RESOURCE=<resource_name>$(NC)"; \
		echo "$(YELLOW)Available resources:$(NC)"; \
		terraform state list; \
		exit 1; \
	fi
	@terraform state show $(RESOURCE)

refresh: ## Refresh Terraform state
	@echo "$(BLUE)Refreshing Terraform state for $(ENV) environment...$(NC)"
	@terraform refresh -var-file=$(TF_VAR_FILE)

cost: ## Estimate infrastructure costs (requires infracost)
	@if command -v infracost >/dev/null 2>&1; then \
		echo "$(BLUE)Estimating costs for $(ENV) environment...$(NC)"; \
		infracost breakdown --path . --terraform-var-file=$(TF_VAR_FILE) --format table; \
	else \
		echo "$(RED)Infracost is not installed. Install from: https://www.infracost.io/docs/#quick-start$(NC)"; \
	fi

security: ## Run security checks (requires tflint)
	@if command -v tflint >/dev/null 2>&1; then \
		echo "$(BLUE)Running security checks...$(NC)"; \
		tflint --init || true; \
		tflint; \
	else \
		echo "$(RED)TFLint is not installed. Install from: https://github.com/terraform-linters/tflint$(NC)"; \
	fi

clean: ## Clean up temporary files
	@echo "$(BLUE)Cleaning up temporary files...$(NC)"
	@rm -f $(PLAN_FILE)* tfplan* terraform.tfstate.backup
	@rm -rf .terraform/modules .terraform/plugins
	@echo "$(GREEN)Cleanup completed$(NC)"

docs: ## Generate Terraform documentation (requires terraform-docs)
	@if command -v terraform-docs >/dev/null 2>&1; then \
		echo "$(BLUE)Generating Terraform documentation...$(NC)"; \
		terraform-docs markdown table --output-file README.md .; \
		echo "$(GREEN)Documentation generated in README.md$(NC)"; \
	else \
		echo "$(RED)terraform-docs is not installed. Install from: https://terraform-docs.io/$(NC)"; \
	fi

upgrade: ## Upgrade Terraform providers
	@echo "$(BLUE)Upgrading Terraform providers...$(NC)"
	@terraform init -upgrade

graph: ## Generate dependency graph (requires graphviz)
	@if command -v dot >/dev/null 2>&1; then \
		echo "$(BLUE)Generating dependency graph...$(NC)"; \
		terraform graph | dot -Tpng > terraform-graph-$(ENV).png; \
		echo "$(GREEN)Graph saved as terraform-graph-$(ENV).png$(NC)"; \
	else \
		echo "$(RED)Graphviz is not installed. Install with: sudo apt install graphviz$(NC)"; \
	fi

# Environment-specific targets
dev: ## Deploy to development environment
	@$(MAKE) apply ENV=dev

staging: ## Deploy to staging environment
	@$(MAKE) apply ENV=staging

prod: ## Deploy to production environment
	@echo "$(YELLOW)Deploying to production - please confirm...$(NC)"
	@$(MAKE) apply ENV=prod

# Quick deployment targets
quick-dev: ## Quick deployment to dev (format, validate, apply)
	@$(MAKE) format validate apply ENV=dev

quick-staging: ## Quick deployment to staging (format, validate, apply)
	@$(MAKE) format validate apply ENV=staging

# Utility targets
check-aws: ## Check AWS credentials and permissions
	@echo "$(BLUE)Checking AWS credentials...$(NC)"
	@aws sts get-caller-identity || (echo "$(RED)AWS credentials not configured$(NC)" && exit 1)
	@echo "$(GREEN)AWS credentials are valid$(NC)"

workspace-list: ## List Terraform workspaces
	@terraform workspace list

workspace-show: ## Show current Terraform workspace
	@terraform workspace show

# All-in-one targets
full-validate: ## Complete validation (format, validate, plan, security, cost)
	@$(MAKE) format-check validate plan security cost ENV=$(ENV)

deploy: ## Full deployment workflow (validate and apply)
	@$(MAKE) full-validate apply ENV=$(ENV)