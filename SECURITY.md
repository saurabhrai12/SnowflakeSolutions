# Security Guidelines

## 🔐 Credential Protection

### **NEVER commit these files to git:**
- `.env` files with real credentials
- `credentials.json`, `secrets.json`, or similar
- Private keys, certificates, or keystores
- AWS credentials files
- Snowflake connection files

### **✅ Safe practices:**
- Use `.env.example` templates with dummy values
- Store real credentials in GitHub repository secrets
- Use environment variables in production
- Keep `.gitignore` updated to prevent accidental commits

## 🛡️ What's Protected

### **Files ignored by git:**
```bash
# Environment files
.env
.env.local
.env.development
.env.staging
.env.production

# Credential files
credentials.json
secrets.json
*.pem
*.key

# Snowflake
.snowsql/
connections.toml

# AWS
.aws/credentials
```

### **Template files included:**
- `python-report-service/.env.example`
- `streamlit-app/.env.example`
- `jenkins/.env.example`
- `terraform.tfvars.example`

## 🚨 If Credentials Were Committed

If you accidentally commit credentials:

1. **Immediately rotate/change all exposed credentials**
2. **Remove from git history:**
   ```bash
   git filter-branch --force --index-filter \
   'git rm --cached --ignore-unmatch path/to/secret/file' \
   --prune-empty --tag-name-filter cat -- --all
   ```
3. **Force push** (if safe to do so):
   ```bash
   git push --force --all
   ```

## 📋 Production Deployment

### **Environment Variables Required:**
```bash
# Snowflake (per environment)
SNOWFLAKE_ACCOUNT
SNOWFLAKE_USER  
SNOWFLAKE_PASSWORD
SNOWFLAKE_DATABASE
SNOWFLAKE_WAREHOUSE

# AWS (if using ECS)
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
```

### **GitHub Actions Secrets:**
All credentials stored as repository secrets in GitHub:
- `SNOWFLAKE_DEV_*`
- `SNOWFLAKE_STAGING_*` 
- `SNOWFLAKE_PROD_*`

## ✅ Security Checklist

Before any commit:
- [ ] No `.env` files with real credentials
- [ ] No hardcoded passwords in code
- [ ] All secrets use environment variables
- [ ] `.gitignore` is comprehensive
- [ ] Example files have dummy values only

## 🔍 Regular Security Audits

Monthly security checks:
```bash
# Check for accidentally tracked credentials
git ls-files | grep -E "\.(env|key|pem|json)$"

# Search for hardcoded passwords
grep -r -i "password\|secret\|key" --include="*.py" --include="*.sql" .

# Verify gitignore is working
git status --ignored | grep -E "\.(env|key|pem)$"
```

Remember: **When in doubt, don't commit it!** 🔒