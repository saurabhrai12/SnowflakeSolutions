# Snowflake Analytics Platform - Infrastructure Management
# ===========================================================

# Configuration
PROJECT_NAME := snowflake-analytics
AWS_REGION := us-east-1
AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
TERRAFORM_DIR := terraform
REPORT_SERVICE_DIR := python-report-service
STREAMLIT_APP_DIR := streamlit-app

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# Ensure terraform is available
TERRAFORM := $(shell command -v terraform 2> /dev/null)
ifndef TERRAFORM
$(error "Terraform is not available. Please install terraform")
endif

# Ensure AWS CLI is available
AWS_CLI := $(shell command -v aws 2> /dev/null)
ifndef AWS_CLI
$(error "AWS CLI is not available. Please install aws-cli")
endif

# Ensure Docker is available
DOCKER := $(shell command -v docker 2> /dev/null)
ifndef DOCKER
$(error "Docker is not available. Please install docker")
endif

.PHONY: help
help: ## Show this help message
	@echo "$(CYAN)Snowflake Analytics Platform - Infrastructure Management$(NC)"
	@echo "============================================================"
	@echo ""
	@echo "$(YELLOW)Available commands:$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(BLUE)%-25s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Infrastructure Commands:$(NC)"
	@echo "  $(GREEN)make init$(NC)           - Initialize Terraform and create terraform.tfvars"
	@echo "  $(GREEN)make plan$(NC)           - Show infrastructure changes"
	@echo "  $(GREEN)make deploy$(NC)         - Deploy complete infrastructure"
	@echo "  $(GREEN)make destroy$(NC)        - Destroy all infrastructure"
	@echo ""
	@echo "$(YELLOW)Service Management:$(NC)"
	@echo "  $(GREEN)make build-all$(NC)      - Build and push all Docker images"
	@echo "  $(GREEN)make deploy-services$(NC) - Deploy services with current images"
	@echo "  $(GREEN)make stop-services$(NC)  - Stop all services (scale to 0)"
	@echo "  $(GREEN)make start-services$(NC) - Start all services (scale to 1)"
	@echo ""
	@echo "$(YELLOW)Individual Services:$(NC)"
	@echo "  $(GREEN)make build-report$(NC)   - Build and push report service image"
	@echo "  $(GREEN)make build-streamlit$(NC) - Build and push Streamlit service image"
	@echo ""
	@echo "$(YELLOW)Monitoring & Debugging:$(NC)"
	@echo "  $(GREEN)make status$(NC)         - Show status of all services"
	@echo "  $(GREEN)make logs-report$(NC)    - Show report service logs"
	@echo "  $(GREEN)make logs-streamlit$(NC) - Show Streamlit service logs"
	@echo "  $(GREEN)make get-urls$(NC)       - Get public URLs of running services"
	@echo ""

# =============================================================================
# Terraform Infrastructure Management
# =============================================================================

.PHONY: init
init: ## Initialize Terraform and create terraform.tfvars
	@echo "$(CYAN)🚀 Initializing Terraform...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform init
	@if [ ! -f $(TERRAFORM_DIR)/terraform.tfvars ]; then \
		echo "$(YELLOW)📝 Creating terraform.tfvars from example...$(NC)"; \
		cp $(TERRAFORM_DIR)/terraform.tfvars.example $(TERRAFORM_DIR)/terraform.tfvars; \
		echo "$(GREEN)✅ Created terraform.tfvars. Please review and update the values.$(NC)"; \
	else \
		echo "$(GREEN)✅ terraform.tfvars already exists.$(NC)"; \
	fi

.PHONY: validate
validate: ## Validate Terraform configuration
	@echo "$(CYAN)🔍 Validating Terraform configuration...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform validate
	@echo "$(GREEN)✅ Terraform configuration is valid.$(NC)"

.PHONY: plan
plan: init validate ## Show infrastructure changes that will be applied
	@echo "$(CYAN)📋 Planning infrastructure changes...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform plan

.PHONY: deploy
deploy: init validate ## Deploy complete infrastructure (ECR + ECS)
	@echo "$(CYAN)🚀 Deploying infrastructure...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform apply -auto-approve
	@echo "$(GREEN)✅ Infrastructure deployed successfully!$(NC)"
	@$(MAKE) show-deployment-info

.PHONY: destroy
destroy: ## Destroy all infrastructure
	@echo "$(RED)⚠️  WARNING: This will destroy ALL infrastructure!$(NC)"
	@echo "$(YELLOW)Press Ctrl+C to cancel, or wait 10 seconds to continue...$(NC)"
	@sleep 10
	@echo "$(CYAN)🗑️  Destroying infrastructure...$(NC)"
	@cd $(TERRAFORM_DIR) && terraform destroy -auto-approve
	@echo "$(GREEN)✅ Infrastructure destroyed.$(NC)"

.PHONY: show-deployment-info
show-deployment-info: ## Show deployment information
	@echo "$(CYAN)📊 Deployment Information:$(NC)"
	@cd $(TERRAFORM_DIR) && terraform output deployment_instructions

# =============================================================================
# Docker Image Management
# =============================================================================

.PHONY: check-ecr
check-ecr: ## Check if ECR repositories exist
	@echo "$(CYAN)🔍 Checking ECR repositories...$(NC)"
	@if aws ecr describe-repositories --repository-names $(PROJECT_NAME)-report-service >/dev/null 2>&1; then \
		echo "$(GREEN)✅ Report service ECR repository exists$(NC)"; \
	else \
		echo "$(RED)❌ Report service ECR repository not found. Run 'make deploy' first.$(NC)"; \
		exit 1; \
	fi
	@if aws ecr describe-repositories --repository-names $(PROJECT_NAME)-streamlit-service >/dev/null 2>&1; then \
		echo "$(GREEN)✅ Streamlit service ECR repository exists$(NC)"; \
	else \
		echo "$(RED)❌ Streamlit service ECR repository not found. Run 'make deploy' first.$(NC)"; \
		exit 1; \
	fi

.PHONY: ecr-login
ecr-login: ## Login to ECR
	@echo "$(CYAN)🔐 Logging into ECR...$(NC)"
	@aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
	@echo "$(GREEN)✅ Logged into ECR successfully.$(NC)"

.PHONY: build-report
build-report: check-ecr ecr-login ## Build and push report service Docker image
	@echo "$(CYAN)🐳 Building report service image...$(NC)"
	@cd $(REPORT_SERVICE_DIR) && docker build --platform linux/amd64 -t $(PROJECT_NAME)-report-service:latest .
	@docker tag $(PROJECT_NAME)-report-service:latest $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(PROJECT_NAME)-report-service:latest
	@echo "$(CYAN)⬆️  Pushing report service image to ECR...$(NC)"
	@docker push $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(PROJECT_NAME)-report-service:latest
	@echo "$(GREEN)✅ Report service image built and pushed successfully.$(NC)"

.PHONY: build-streamlit
build-streamlit: check-ecr ecr-login ## Build and push Streamlit service Docker image
	@echo "$(CYAN)🐳 Building Streamlit service image...$(NC)"
	@cd $(STREAMLIT_APP_DIR) && docker build --platform linux/amd64 -t $(PROJECT_NAME)-streamlit-service:latest .
	@docker tag $(PROJECT_NAME)-streamlit-service:latest $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(PROJECT_NAME)-streamlit-service:latest
	@echo "$(CYAN)⬆️  Pushing Streamlit service image to ECR...$(NC)"
	@docker push $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(PROJECT_NAME)-streamlit-service:latest
	@echo "$(GREEN)✅ Streamlit service image built and pushed successfully.$(NC)"

.PHONY: build-all
build-all: build-report build-streamlit ## Build and push all Docker images
	@echo "$(GREEN)✅ All images built and pushed successfully.$(NC)"

# =============================================================================
# Service Management
# =============================================================================

.PHONY: deploy-services
deploy-services: build-all ## Deploy services with current images
	@echo "$(CYAN)🚀 Deploying services...$(NC)"
	@aws ecs update-service --cluster $(PROJECT_NAME)-cluster --service $(PROJECT_NAME)-report-service --force-new-deployment >/dev/null
	@aws ecs update-service --cluster $(PROJECT_NAME)-cluster --service $(PROJECT_NAME)-streamlit-service --force-new-deployment >/dev/null
	@echo "$(GREEN)✅ Services deployment initiated. Use 'make status' to check progress.$(NC)"

.PHONY: stop-services
stop-services: ## Stop all services (scale to 0)
	@echo "$(YELLOW)⏹️  Stopping all services...$(NC)"
	@aws ecs update-service --cluster $(PROJECT_NAME)-cluster --service $(PROJECT_NAME)-report-service --desired-count 0 >/dev/null
	@aws ecs update-service --cluster $(PROJECT_NAME)-cluster --service $(PROJECT_NAME)-streamlit-service --desired-count 0 >/dev/null
	@echo "$(GREEN)✅ All services stopped.$(NC)"

.PHONY: start-services
start-services: ## Start all services (scale to 1)
	@echo "$(GREEN)▶️  Starting all services...$(NC)"
	@aws ecs update-service --cluster $(PROJECT_NAME)-cluster --service $(PROJECT_NAME)-report-service --desired-count 1 >/dev/null
	@aws ecs update-service --cluster $(PROJECT_NAME)-cluster --service $(PROJECT_NAME)-streamlit-service --desired-count 1 >/dev/null
	@echo "$(GREEN)✅ All services started.$(NC)"

.PHONY: restart-services
restart-services: stop-services start-services ## Restart all services
	@echo "$(GREEN)🔄 Services restarted.$(NC)"

# =============================================================================
# Monitoring & Status
# =============================================================================

.PHONY: status
status: ## Show status of all services
	@echo "$(CYAN)📊 Service Status:$(NC)"
	@echo ""
	@echo "$(YELLOW)ECS Cluster:$(NC)"
	@aws ecs describe-clusters --clusters $(PROJECT_NAME)-cluster --query 'clusters[0].{Name:clusterName,Status:status,ActiveServices:activeServicesCount,RunningTasks:runningTasksCount,PendingTasks:pendingTasksCount}' --output table 2>/dev/null || echo "❌ Cluster not found"
	@echo ""
	@echo "$(YELLOW)Report Service:$(NC)"
	@aws ecs describe-services --cluster $(PROJECT_NAME)-cluster --services $(PROJECT_NAME)-report-service --query 'services[0].{Name:serviceName,Status:status,DesiredCount:desiredCount,RunningCount:runningCount,PendingCount:pendingCount}' --output table 2>/dev/null || echo "❌ Report service not found"
	@echo ""
	@echo "$(YELLOW)Streamlit Service:$(NC)"
	@aws ecs describe-services --cluster $(PROJECT_NAME)-cluster --services $(PROJECT_NAME)-streamlit-service --query 'services[0].{Name:serviceName,Status:status,DesiredCount:desiredCount,RunningCount:runningCount,PendingCount:pendingCount}' --output table 2>/dev/null || echo "❌ Streamlit service not found"

.PHONY: get-urls
get-urls: ## Get public URLs of running services
	@echo "$(CYAN)🌐 Getting service URLs...$(NC)"
	@echo ""
	@echo "$(YELLOW)Report Service URL:$(NC)"
	@./scripts/get-service-url.sh $(PROJECT_NAME)-cluster $(PROJECT_NAME)-report-service 8000
	@echo ""
	@echo "$(YELLOW)Streamlit Service URL:$(NC)"
	@./scripts/get-service-url.sh $(PROJECT_NAME)-cluster $(PROJECT_NAME)-streamlit-service 8501

.PHONY: logs-report
logs-report: ## Show report service logs
	@echo "$(CYAN)📋 Report Service Logs:$(NC)"
	@aws logs tail /ecs/$(PROJECT_NAME)-report-service --follow

.PHONY: logs-streamlit
logs-streamlit: ## Show Streamlit service logs
	@echo "$(CYAN)📋 Streamlit Service Logs:$(NC)"
	@aws logs tail /ecs/$(PROJECT_NAME)-streamlit-service --follow

# =============================================================================
# Development & Testing
# =============================================================================

.PHONY: test-local
test-local: ## Test services locally with Docker Compose
	@echo "$(CYAN)🧪 Testing services locally...$(NC)"
	@if [ -f docker-compose.yml ]; then \
		docker-compose up --build -d; \
		echo "$(GREEN)✅ Services started locally. Check http://localhost:8000 and http://localhost:8501$(NC)"; \
	else \
		echo "$(RED)❌ docker-compose.yml not found$(NC)"; \
	fi

.PHONY: test-local-down
test-local-down: ## Stop local Docker Compose services
	@echo "$(YELLOW)⏹️  Stopping local services...$(NC)"
	@docker-compose down
	@echo "$(GREEN)✅ Local services stopped.$(NC)"

# =============================================================================
# Utility Commands
# =============================================================================

.PHONY: clean
clean: ## Clean up local Docker images and containers
	@echo "$(YELLOW)🧹 Cleaning up local Docker resources...$(NC)"
	@docker system prune -f
	@echo "$(GREEN)✅ Docker cleanup completed.$(NC)"

.PHONY: terraform-state
terraform-state: ## Show Terraform state
	@echo "$(CYAN)📋 Terraform State:$(NC)"
	@cd $(TERRAFORM_DIR) && terraform state list

.PHONY: check-prerequisites
check-prerequisites: ## Check if all required tools are installed
	@echo "$(CYAN)🔍 Checking prerequisites...$(NC)"
	@echo -n "Terraform: "
	@if command -v terraform >/dev/null 2>&1; then echo "$(GREEN)✅ Found$(NC)"; else echo "$(RED)❌ Not found$(NC)"; fi
	@echo -n "AWS CLI: "
	@if command -v aws >/dev/null 2>&1; then echo "$(GREEN)✅ Found$(NC)"; else echo "$(RED)❌ Not found$(NC)"; fi
	@echo -n "Docker: "
	@if command -v docker >/dev/null 2>&1; then echo "$(GREEN)✅ Found$(NC)"; else echo "$(RED)❌ Not found$(NC)"; fi
	@echo -n "jq: "
	@if command -v jq >/dev/null 2>&1; then echo "$(GREEN)✅ Found$(NC)"; else echo "$(RED)❌ Not found$(NC)"; fi
	@echo ""
	@echo "$(YELLOW)AWS Configuration:$(NC)"
	@aws sts get-caller-identity --query '{Account:Account,User:Arn}' --output table 2>/dev/null || echo "$(RED)❌ AWS not configured$(NC)"

# =============================================================================
# Quick Commands
# =============================================================================

.PHONY: up
up: deploy build-all deploy-services ## Complete deployment (infrastructure + services)
	@echo "$(GREEN)🎉 Complete deployment finished!$(NC)"
	@echo "$(CYAN)Use 'make get-urls' to get service URLs$(NC)"

.PHONY: down
down: destroy ## Complete teardown (destroy all infrastructure)
	@echo "$(GREEN)🎉 Complete teardown finished!$(NC)"

# =============================================================================
# Help for common workflows
# =============================================================================

.PHONY: first-time-setup
first-time-setup: check-prerequisites init plan ## First time setup guide
	@echo ""
	@echo "$(CYAN)🎯 First Time Setup Complete!$(NC)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "1. Review $(TERRAFORM_DIR)/terraform.tfvars and update values if needed"
	@echo "2. Run '$(GREEN)make deploy$(NC)' to create infrastructure"
	@echo "3. Run '$(GREEN)make build-all$(NC)' to build and push Docker images"
	@echo "4. Run '$(GREEN)make deploy-services$(NC)' to start services"
	@echo "5. Run '$(GREEN)make get-urls$(NC)' to get service URLs"
	@echo ""
	@echo "Or use '$(GREEN)make up$(NC)' to do steps 2-4 in one command"

.PHONY: production-deploy
production-deploy: ## Production deployment with confirmation
	@echo "$(RED)⚠️  WARNING: This will deploy to PRODUCTION!$(NC)"
	@echo "$(YELLOW)Press Ctrl+C to cancel, or wait 10 seconds to continue...$(NC)"
	@sleep 10
	@$(MAKE) up