#!/bin/bash

# Streamlit ECS Deployment Script
# This script deploys the Streamlit app infrastructure and services to AWS ECS Fargate

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
STACK_NAME=""
VPC_ID=""
SUBNET_IDS=""
DOMAIN_NAME=""
CERTIFICATE_ARN=""

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
    echo "  -v, --vpc-id         VPC ID (required)"
    echo "  -s, --subnet-ids     Subnet IDs (comma-separated, required)"
    echo "  -d, --domain         Custom domain name (optional)"
    echo "  -c, --certificate    SSL Certificate ARN (optional)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e dev -v vpc-12345 -s subnet-12345,subnet-67890"
    echo "  $0 -e prod -v vpc-12345 -s subnet-12345,subnet-67890 -d streamlit.example.com -c arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
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

# Validate required parameters
if [[ -z "$VPC_ID" ]] || [[ -z "$SUBNET_IDS" ]]; then
    print_message $RED "Error: VPC ID and Subnet IDs are required"
    show_usage
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_message $RED "Error: Environment must be one of: dev, staging, prod"
    exit 1
fi

# Set stack name
STACK_NAME="${PROJECT_NAME}-streamlit-${ENVIRONMENT}"

print_message $BLUE "🚀 Starting Streamlit ECS Deployment"
print_message $BLUE "======================================"
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "Project: $PROJECT_NAME"
echo "Stack Name: $STACK_NAME"
echo "VPC ID: $VPC_ID"
echo "Subnet IDs: $SUBNET_IDS"
echo "Domain: ${DOMAIN_NAME:-'N/A'}"
echo "Certificate: ${CERTIFICATE_ARN:-'N/A'}"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    print_message $RED "Error: AWS CLI not configured or credentials invalid"
    exit 1
fi

# Get account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_message $GREEN "✅ AWS Account ID: $AWS_ACCOUNT_ID"

# Convert subnet IDs to CloudFormation format
SUBNET_LIST=$(echo "$SUBNET_IDS" | sed 's/,/\\,/g')

# Prepare CloudFormation parameters
PARAMETERS=(
    "ParameterKey=ProjectName,ParameterValue=$PROJECT_NAME"
    "ParameterKey=Environment,ParameterValue=$ENVIRONMENT"
    "ParameterKey=VpcId,ParameterValue=$VPC_ID"
    "ParameterKey=SubnetIds,ParameterValue=\"$SUBNET_IDS\""
)

if [[ -n "$DOMAIN_NAME" ]]; then
    PARAMETERS+=("ParameterKey=DomainName,ParameterValue=$DOMAIN_NAME")
fi

if [[ -n "$CERTIFICATE_ARN" ]]; then
    PARAMETERS+=("ParameterKey=CertificateArn,ParameterValue=$CERTIFICATE_ARN")
fi

# Check if stack exists
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    print_message $YELLOW "⚡ Updating existing CloudFormation stack..."
    OPERATION="update-stack"
else
    print_message $GREEN "🆕 Creating new CloudFormation stack..."
    OPERATION="create-stack"
fi

# Deploy CloudFormation stack
print_message $BLUE "📋 Deploying CloudFormation template..."

aws cloudformation $OPERATION \
    --stack-name "$STACK_NAME" \
    --template-body file://cloudformation-template.yml \
    --parameters "${PARAMETERS[@]}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$AWS_REGION" \
    --tags \
        Key=Environment,Value="$ENVIRONMENT" \
        Key=Project,Value="$PROJECT_NAME" \
        Key=ManagedBy,Value=CloudFormation

# Wait for stack operation to complete
print_message $YELLOW "⏳ Waiting for stack operation to complete..."

if [[ "$OPERATION" == "create-stack" ]]; then
    aws cloudformation wait stack-create-complete \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION"
else
    aws cloudformation wait stack-update-complete \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION"
fi

# Get stack outputs
print_message $BLUE "📊 Getting stack outputs..."

LOAD_BALANCER_DNS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
    --output text)

STREAMLIT_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`StreamlitAppURL`].OutputValue' \
    --output text)

ECR_REPOSITORY_URI=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ECRRepositoryURI`].OutputValue' \
    --output text)

ECS_CLUSTER_NAME=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ECSClusterName`].OutputValue' \
    --output text)

# Create secrets in AWS Secrets Manager
print_message $BLUE "🔐 Setting up AWS Secrets Manager..."

SECRET_NAME="streamlit/$ENVIRONMENT/snowflake"

# Check if secret exists
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    print_message $YELLOW "⚠️  Secret $SECRET_NAME already exists. Skipping creation."
    print_message $YELLOW "    You may need to update it manually with the correct Snowflake credentials."
else
    # Create secret with placeholder values
    aws secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "Snowflake credentials for Streamlit app ($ENVIRONMENT)" \
        --secret-string '{
            "ACCOUNT": "YOUR_SNOWFLAKE_ACCOUNT",
            "USER": "YOUR_SNOWFLAKE_USER", 
            "PASSWORD": "YOUR_SNOWFLAKE_PASSWORD",
            "DATABASE": "analytics_platform_'$ENVIRONMENT'",
            "WAREHOUSE": "analytics_wh_'$ENVIRONMENT'"
        }' \
        --region "$AWS_REGION" \
        --tags '[
            {"Key": "Environment", "Value": "'$ENVIRONMENT'"},
            {"Key": "Project", "Value": "'$PROJECT_NAME'"},
            {"Key": "Application", "Value": "streamlit-app"}
        ]'
    
    print_message $GREEN "✅ Created secret: $SECRET_NAME"
    print_message $YELLOW "⚠️  Please update the secret with your actual Snowflake credentials:"
    print_message $YELLOW "    aws secretsmanager update-secret --secret-id $SECRET_NAME --secret-string '{\"ACCOUNT\":\"your_account\",\"USER\":\"your_user\",\"PASSWORD\":\"your_password\",\"DATABASE\":\"analytics_platform_$ENVIRONMENT\",\"WAREHOUSE\":\"analytics_wh_$ENVIRONMENT\"}'"
fi

# Print deployment summary
print_message $GREEN "🎉 Deployment Summary"
print_message $GREEN "===================="
echo "Stack Name: $STACK_NAME"
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "Load Balancer DNS: $LOAD_BALANCER_DNS"
echo "Streamlit App URL: $STREAMLIT_URL"
echo "ECR Repository: $ECR_REPOSITORY_URI"
echo "ECS Cluster: $ECS_CLUSTER_NAME"
echo ""
print_message $GREEN "Next Steps:"
echo "1. Update the secret with your Snowflake credentials:"
echo "   aws secretsmanager update-secret --secret-id $SECRET_NAME --secret-string '{\"ACCOUNT\":\"your_account\",\"USER\":\"your_user\",\"PASSWORD\":\"your_password\",\"DATABASE\":\"analytics_platform_$ENVIRONMENT\",\"WAREHOUSE\":\"analytics_wh_$ENVIRONMENT\"}'"
echo ""
echo "2. Build and push your Docker image:"
echo "   docker build -t $ECR_REPOSITORY_URI:$ENVIRONMENT-latest ../../../streamlit-app"
echo "   aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY_URI"
echo "   docker push $ECR_REPOSITORY_URI:$ENVIRONMENT-latest"
echo ""
echo "3. Update the ECS service to use the new image (this happens automatically via GitHub Actions)"
echo ""
print_message $GREEN "✅ Infrastructure deployment completed successfully!"