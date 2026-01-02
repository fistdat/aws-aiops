# Claude Configuration for AWS AIOps Project

This directory contains configuration files that guide Claude's behavior when working on this project.

## Files

### `rules`
Comprehensive rules enforcing 100% Infrastructure as Code (IaC) compliance.

**Key Requirements**:
- All infrastructure changes MUST use Terraform
- No manual AWS CLI resource creation
- No manual package installations without Terraform provisioners
- All configuration files must be version controlled
- Proper file change detection via MD5 triggers

### `QUICK-REFERENCE.md`
Quick reference card for common IaC patterns and commands.

## Usage

Claude will automatically read and follow these rules when:
1. Proposing infrastructure changes
2. Implementing new features
3. Fixing bugs or issues
4. Deploying code or configurations

## For Developers

**To modify rules**:
1. Edit `.claude/rules` file
2. Update version number
3. Test with sample Terraform operations
4. Commit to Git

**To verify compliance**:
```bash
# Check if all changes are in Terraform
git status
terraform plan  # Should match actual infrastructure

# Verify no manual changes
aws iot list-things --region ap-southeast-1
# Compare with terraform state show
```

## Enforcement

Claude will:
- ✅ Always propose Terraform solutions first
- ✅ Reject manual commands unless emergency approved
- ✅ Validate all Terraform before applying
- ✅ Document all deployments
- ✅ Maintain audit trail

## Questions?

See full rules documentation: `.claude/rules`

---

**IaC Compliance Level**: 100%  
**Last Updated**: 2025-12-31
