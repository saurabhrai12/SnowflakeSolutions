#!/bin/bash

# GitHub Repository Secrets Setup Script
# Run this script to automatically set up all Snowflake secrets

echo "🔐 Setting up GitHub repository secrets for Snowflake deployment..."

# Check if authenticated with GitHub
if ! gh auth status > /dev/null 2>&1; then
    echo "❌ Not authenticated with GitHub CLI"
    echo "🔑 Please run: gh auth login"
    echo "   Follow the prompts to authenticate with GitHub"
    exit 1
fi

echo "✅ GitHub CLI authenticated"

# Set DEV environment secrets
echo "🏗️ Setting up DEV environment secrets..."
gh secret set SNOWFLAKE_DEV_ACCOUNT --body "BIREZNC-ZHB27778.snowflakecomputing.com"
gh secret set SNOWFLAKE_DEV_USER --body "SAURABHMAC"
gh secret set SNOWFLAKE_DEV_PASSWORD --body "AwsSnowAdmin1234"

# Set STAGING environment secrets
echo "🔄 Setting up STAGING environment secrets..."
gh secret set SNOWFLAKE_STAGING_ACCOUNT --body "BIREZNC-ZHB27778.snowflakecomputing.com"
gh secret set SNOWFLAKE_STAGING_USER --body "SAURABHMAC"
gh secret set SNOWFLAKE_STAGING_PASSWORD --body "AwsSnowAdmin1234"

# Set PROD environment secrets
echo "🚀 Setting up PROD environment secrets..."
gh secret set SNOWFLAKE_PROD_ACCOUNT --body "BIREZNC-ZHB27778.snowflakecomputing.com"
gh secret set SNOWFLAKE_PROD_USER --body "SAURABHMAC"
gh secret set SNOWFLAKE_PROD_PASSWORD --body "prod-user-password"

echo ""
echo "✅ All secrets have been set up successfully!"
echo ""

# Verify secrets were created
echo "🔍 Verifying secrets..."
gh secret list

echo ""
echo "🎉 GitHub repository is now ready for Snowflake deployment!"
echo ""
echo "📋 Next steps:"
echo "1. Go to GitHub Actions tab in your repository"
echo "2. Find 'Snowflake Deployment Pipeline' workflow"
echo "3. Click 'Run workflow' to test deployment"
echo "4. Select 'DEV' environment with 'Dry Run: true' for initial test"
echo ""
echo "🔗 Workflow file: .github/workflows/snowflake-deployment.yml"