#!/bin/bash

# Streamlit ECS Terraform Deployment Script
# This script deploys the Streamlit app infrastructure using Terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="dev"
AWS_REGION="us-east-1"
PROJECT_NAME="snowflake-analytics"
VPC_ID=""
SUBNET_IDS=""
DOMAIN_NAME=""
CERTIFICATE_ARN=""
AUTO_APPROVE=false
DESTROY=false
PLAN_ONLY=false
FORCE_INIT=false

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -e, --environment    Environment (dev|staging|prod) [default: dev]"
    echo "  -r, --region         AWS region [default: us-east-1]"
    echo "  -p, --project        Project name [default: snowflake-analytics]"
    echo "  -v, --vpc-id         VPC ID (optional - can be set in tfvars)"
    echo "  -s, --subnet-ids     Subnet IDs (comma-separated, optional - can be set in tfvars)"
    echo "  -d, --domain         Custom domain name (optional)"
    echo "  -c, --certificate    SSL Certificate ARN (optional)"
    echo "  -a, --auto-approve   Auto-approve terraform apply"
    echo "  --destroy            Destroy infrastructure"
    echo "  --plan-only          Run terraform plan only"
    echo "  --force-init         Force terraform init (ignore existing state)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e dev                                    # Deploy to dev using tfvars file"
    echo "  $0 -e dev -v vpc-12345 -s subnet-12345,subnet-67890  # Override VPC/subnets"
    echo "  $0 -e prod -a                                # Deploy to prod with auto-approve"
    echo "  $0 -e staging --plan-only                    # Plan staging deployment"
    echo "  $0 -e dev --destroy                          # Destroy dev infrastructure"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--region)
            AWS_REGION="$2"
            shift 2
            ;;
        -p|--project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -v|--vpc-id)
            VPC_ID="$2"
            shift 2
            ;;
        -s|--subnet-ids)
            SUBNET_IDS="$2"
            shift 2
            ;;
        -d|--domain)
            DOMAIN_NAME="$2"
            shift 2
            ;;
        -c|--certificate)
            CERTIFICATE_ARN="$2"
            shift 2
            ;;
        -a|--auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --destroy)
            DESTROY=true
            shift
            ;;
        --plan-only)
            PLAN_ONLY=true
            shift
            ;;
        --force-init)
            FORCE_INIT=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_message $RED "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_message $RED "Error: Environment must be one of: dev, staging, prod"
    exit 1
fi

print_message $BLUE "🚀 Starting Terraform Streamlit ECS Deployment"
print_message $BLUE "=============================================="
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "Project: $PROJECT_NAME"
echo "VPC ID: ${VPC_ID:-'From tfvars file'}"
echo "Subnet IDs: ${SUBNET_IDS:-'From tfvars file'}"
echo "Domain: ${DOMAIN_NAME:-'From tfvars file or none'}"
echo "Certificate: ${CERTIFICATE_ARN:-'From tfvars file or none'}"
echo "Auto Approve: $AUTO_APPROVE"
echo "Destroy: $DESTROY"
echo "Plan Only: $PLAN_ONLY"
echo ""

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_message $RED "Error: Terraform is not installed"
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_message $RED "Error: AWS CLI not configured or credentials invalid"
    exit 1
fi

# Get account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_message $GREEN "✅ AWS Account ID: $AWS_ACCOUNT_ID"

# Set up file paths
TFVARS_FILE="environments/${ENVIRONMENT}.tfvars"
BACKEND_CONFIG="environments/${ENVIRONMENT}.backend"

# Check if environment-specific files exist
if [[ ! -f "$TFVARS_FILE" ]]; then
    print_message $RED "Error: Environment file $TFVARS_FILE not found"
    exit 1
fi

if [[ ! -f "$BACKEND_CONFIG" ]]; then
    print_message $RED "Error: Backend config file $BACKEND_CONFIG not found"
    exit 1
fi

# Initialize Terraform
if [[ ! -d ".terraform" ]] || [[ "$FORCE_INIT" == "true" ]]; then
    print_message $BLUE "🔧 Initializing Terraform..."
    terraform init -backend-config="$BACKEND_CONFIG" -upgrade
else
    print_message $YELLOW "⚡ Terraform already initialized (use --force-init to reinitialize)"
fi

# Validate Terraform configuration
print_message $BLUE "🔍 Validating Terraform configuration..."
terraform validate

# Prepare terraform variables
TF_VAR_ARGS=("-var-file=$TFVARS_FILE")

# Override variables if provided via command line
if [[ -n "$VPC_ID" ]]; then
    TF_VAR_ARGS+=("-var=vpc_id=$VPC_ID")
fi

if [[ -n "$SUBNET_IDS" ]]; then
    # Convert comma-separated list to Terraform list format
    SUBNET_LIST="[\"$(echo "$SUBNET_IDS" | sed 's/,/","/g')\"]"
    TF_VAR_ARGS+=("-var=subnet_ids=$SUBNET_LIST")
fi

if [[ -n "$DOMAIN_NAME" ]]; then
    TF_VAR_ARGS+=("-var=domain_name=$DOMAIN_NAME")
fi

if [[ -n "$CERTIFICATE_ARN" ]]; then
    TF_VAR_ARGS+=("-var=certificate_arn=$CERTIFICATE_ARN")
fi

if [[ -n "$AWS_REGION" ]]; then
    TF_VAR_ARGS+=("-var=aws_region=$AWS_REGION")
fi

if [[ -n "$PROJECT_NAME" ]]; then
    TF_VAR_ARGS+=("-var=project_name=$PROJECT_NAME")
fi

# Run terraform plan
print_message $BLUE "📋 Planning Terraform deployment..."
if [[ "$DESTROY" == "true" ]]; then
    terraform plan -destroy "${TF_VAR_ARGS[@]}" -out=tfplan
else
    terraform plan "${TF_VAR_ARGS[@]}" -out=tfplan
fi

# Exit if plan only
if [[ "$PLAN_ONLY" == "true" ]]; then
    print_message $GREEN "✅ Terraform plan completed. Review the plan above."
    print_message $YELLOW "To apply the plan, run: terraform apply tfplan"
    exit 0
fi

# Apply terraform changes
if [[ "$DESTROY" == "true" ]]; then
    print_message $YELLOW "⚠️  DESTROYING infrastructure for environment: $ENVIRONMENT"
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        terraform apply -auto-approve tfplan
    else
        echo ""
        read -p "Are you sure you want to DESTROY the infrastructure? Type 'yes' to confirm: " confirm
        if [[ "$confirm" == "yes" ]]; then
            terraform apply tfplan
        else
            print_message $YELLOW "❌ Destruction cancelled"
            exit 1
        fi
    fi
else
    print_message $BLUE "🚀 Applying Terraform configuration..."
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        terraform apply -auto-approve tfplan
    else
        terraform apply tfplan
    fi
fi

# Clean up plan file
rm -f tfplan

if [[ "$DESTROY" == "true" ]]; then
    print_message $GREEN "🗑️  Infrastructure destroyed successfully!"
    exit 0
fi

# Get outputs
print_message $BLUE "📊 Getting deployment outputs..."

LOAD_BALANCER_DNS=$(terraform output -raw load_balancer_dns 2>/dev/null || echo "N/A")
STREAMLIT_URL=$(terraform output -raw streamlit_app_url 2>/dev/null || echo "N/A")
ECR_REPOSITORY_URI=$(terraform output -raw ecr_repository_uri 2>/dev/null || echo "N/A")
ECS_CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "N/A")
ECS_SERVICE_NAME=$(terraform output -raw ecs_service_name 2>/dev/null || echo "N/A")
SECRET_NAME=$(terraform output -raw secrets_manager_secret_name 2>/dev/null || echo "N/A")

# Print deployment summary
print_message $GREEN "🎉 Deployment Summary"
print_message $GREEN "===================="
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "Load Balancer DNS: $LOAD_BALANCER_DNS"
echo "Streamlit App URL: $STREAMLIT_URL"
echo "ECR Repository: $ECR_REPOSITORY_URI"
echo "ECS Cluster: $ECS_CLUSTER_NAME"
echo "ECS Service: $ECS_SERVICE_NAME"
echo "Secrets Manager: $SECRET_NAME"
echo ""

print_message $GREEN "Next Steps:"
echo "1. Update the secret with your Snowflake credentials:"
echo "   aws secretsmanager update-secret --secret-id \"$SECRET_NAME\" --secret-string '{\"ACCOUNT\":\"your_account\",\"USER\":\"your_user\",\"PASSWORD\":\"your_password\",\"DATABASE\":\"analytics_platform_$ENVIRONMENT\",\"WAREHOUSE\":\"analytics_wh_$ENVIRONMENT\"}'"
echo ""
echo "2. Build and push your Docker image:"
echo "   docker build -t $ECR_REPOSITORY_URI:$ENVIRONMENT-latest ../../../streamlit-app"
echo "   aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY_URI"
echo "   docker push $ECR_REPOSITORY_URI:$ENVIRONMENT-latest"
echo ""
echo "3. Update the ECS service (happens automatically via GitHub Actions or run):"
echo "   aws ecs update-service --cluster $ECS_CLUSTER_NAME --service $ECS_SERVICE_NAME --force-new-deployment"
echo ""
print_message $GREEN "✅ Terraform deployment completed successfully!"
print_message $YELLOW "💡 Pro tip: Use 'terraform output' to see all available outputs"