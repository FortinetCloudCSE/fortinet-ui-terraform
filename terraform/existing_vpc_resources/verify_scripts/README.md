# Infrastructure Verification Scripts

This directory contains scripts to verify that AWS infrastructure has been deployed correctly by Terraform.

## Quick Start

### Option 1: Smart Mode (Recommended - Faster)

Use Terraform outputs for verification (no AWS CLI lookups needed):

```bash
# Generate verification data from Terraform outputs
./generate_verification_data.sh

# Run verification
./verify_all.sh --verify all
```

### Option 2: Standard Mode

Verification scripts will automatically fall back to AWS CLI if Terraform data isn't available:

```bash
# Run verification (will use AWS CLI lookups)
./verify_all.sh --verify all
```

## How It Works

### Smart Mode (With Terraform Outputs)

When you run `generate_verification_data.sh`, it:
1. Extracts resource IDs from Terraform outputs
2. Generates a bash-sourceable file: `terraform_verification_data.sh`
3. Verification scripts automatically use this data

**Benefits:**
- ⚡ **Much faster** - No AWS CLI calls needed
- ✅ **More reliable** - Uses exact resource IDs from Terraform
- 🎯 **Accurate** - No risk of tag name mismatches

**When to regenerate:**
- After running `terraform apply` or `terraform destroy`
- After any infrastructure changes
- If verification scripts report unexpected results

```bash
./generate_verification_data.sh
```

### Standard Mode (AWS CLI Lookups)

If `terraform_verification_data.sh` doesn't exist, scripts will:
1. Read configuration from `terraform.tfvars`
2. Use AWS CLI to find resources by tag names
3. Verify each resource exists and is configured correctly

**When to use:**
- Verifying infrastructure not created by Terraform
- When Terraform state is not available
- For debugging or manual verification

## Available Verification Scripts

### Main Scripts

- **`verify_all.sh`** - Master script that runs all verification scripts
  ```bash
  ./verify_all.sh --verify all              # Verify everything
  ./verify_all.sh --verify management       # Verify management VPC only
  ./verify_all.sh --verify inspection       # Verify inspection VPC only
  ./verify_all.sh --verify spoke            # Verify both spoke VPCs
  ./verify_all.sh --verify east             # Verify east VPC only
  ./verify_all.sh --verify west             # Verify west VPC only
  ./verify_all.sh --verify connectivity     # Ping test all public IPs
  ```

- **`verify_summary.sh`** - Display infrastructure summary

### Individual Scripts

- **`verify_management_vpc.sh`** - Verify management VPC, jump box, FortiManager, FortiAnalyzer
- **`verify_inspection_vpc.sh`** - Verify inspection VPC and subnets
- **`verify_east_vpc.sh`** - Verify east spoke VPC and Linux instances
- **`verify_west_vpc.sh`** - Verify west spoke VPC and Linux instances
- **`verify_connectivity.sh`** - Ping test all resources with public IPs (jump box, FortiManager, FortiAnalyzer only - spoke instances have no public IPs)

### Helper Scripts

- **`generate_verification_data.sh`** - Export Terraform outputs for verification
- **`common_functions.sh`** - Shared functions used by all scripts

## Terraform Outputs Integration

### What Gets Exported

The `verification_data` Terraform output includes:

**Management VPC:**
- VPC ID, IGW ID
- Jump box IPs (public/private)
- FortiManager IPs (public/private)
- FortiAnalyzer IPs (public/private)

**Inspection VPC:**
- VPC ID, IGW ID
- All subnet IDs (public, private, GWLB, TGW, NAT GW)
- All route table IDs
- TGW attachment and route table IDs

**Transit Gateway:**
- TGW ID
- Route table IDs for east, west, inspection
- Attachment IDs for all VPCs

**Spoke VPCs (East/West):**
- VPC IDs
- Subnet IDs (public, TGW)
- Route table IDs
- Linux instance IDs and IPs (public/private)

### Viewing Terraform Outputs

```bash
# View all outputs
cd /path/to/terraform/existing_vpc_resources
terraform output

# View specific output
terraform output connection_info

# View verification data in JSON
terraform output -json verification_data

# View pretty-printed JSON
terraform output -json verification_data | jq .
```

## Common Usage Patterns

### After Initial Deployment

```bash
cd verify_scripts

# Generate Terraform data
./generate_verification_data.sh

# Verify everything
./verify_all.sh --verify all

# View summary
./verify_summary.sh

# Test connectivity (ping all public IPs)
./verify_all.sh --verify connectivity
```

### After Infrastructure Changes

```bash
# Regenerate Terraform data to pick up changes
./generate_verification_data.sh

# Re-run verification
./verify_all.sh --verify all
```

### Debugging Specific Components

```bash
# Check just the management VPC
./verify_all.sh --verify management

# Check just spoke VPCs
./verify_all.sh --verify spoke

# Enable debug output
DEBUG=true ./verify_all.sh --verify all
```

### Manual Verification (Without Terraform Data)

```bash
# Remove generated data to force AWS CLI mode
rm -f terraform_verification_data.sh

# Run verification (will use AWS CLI)
./verify_all.sh --verify all
```

## File Structure

```
verify_scripts/
├── README.md                           # This file
├── common_functions.sh                 # Shared verification functions
├── generate_verification_data.sh       # Export Terraform outputs
├── terraform_verification_data.sh      # Generated file (gitignored)
├── verify_all.sh                       # Master verification script
├── verify_summary.sh                   # Infrastructure summary
├── verify_management_vpc.sh            # Management VPC verification
├── verify_inspection_vpc.sh            # Inspection VPC verification
├── verify_east_vpc.sh                  # East spoke VPC verification
└── verify_west_vpc.sh                  # West spoke VPC verification
```

## Troubleshooting

### "Terraform state file not found"

**Problem:** `generate_verification_data.sh` can't find Terraform state

**Solution:** Run from the correct directory or ensure Terraform has been applied
```bash
cd ../  # Go to terraform directory
terraform apply
cd verify_scripts
./generate_verification_data.sh
```

### "Failed to get Terraform output"

**Problem:** Terraform output command failed

**Solution:** Ensure Terraform is initialized and state is valid
```bash
cd ../
terraform init
terraform refresh
cd verify_scripts
./generate_verification_data.sh
```

### Verification Scripts Report Resources Missing

**Problem:** Scripts can't find resources even though they exist

**Solution:** Regenerate Terraform data or check tag names match
```bash
# Regenerate data
./generate_verification_data.sh

# Or check tags match expected pattern
cd ../
grep "^cp " terraform.tfvars
grep "^env " terraform.tfvars
```

### Scripts Running Slow

**Problem:** Verification takes a long time

**Solution:** Use Terraform outputs instead of AWS CLI
```bash
./generate_verification_data.sh
./verify_all.sh --verify all
```

## Performance Comparison

| Mode | Speed | Reliability | Requirements |
|------|-------|-------------|--------------|
| **Smart Mode (Terraform outputs)** | ⚡⚡⚡ Very Fast | ✅ Excellent | Terraform state available |
| **Standard Mode (AWS CLI)** | 🐌 Slower | ⚠️ Good | AWS credentials, correct tags |

**Recommendation:** Always use Smart Mode when Terraform state is available. It's faster, more reliable, and eliminates AWS API rate limiting concerns.

## Best Practices

1. **Always regenerate after changes:**
   ```bash
   terraform apply && cd verify_scripts && ./generate_verification_data.sh
   ```

2. **Add to .gitignore:**
   - `terraform_verification_data.sh` should not be committed (contains environment-specific IDs)

3. **Use in CI/CD:**
   ```bash
   terraform apply
   cd verify_scripts
   ./generate_verification_data.sh
   ./verify_all.sh --verify all || exit 1
   ```

4. **Debug mode for troubleshooting:**
   ```bash
   DEBUG=true ./verify_all.sh --verify all
   ```

## Contributing

When adding new verification checks:

1. Add resource IDs to the `verification_data` output in `outputs.tf`
2. Update `generate_verification_data.sh` to export new variables
3. Use `get_tf_*` helper functions in verification scripts
4. Always provide AWS CLI fallback for compatibility
5. Update this README with new verification capabilities
