"""Tests for the HCL variables.tf parser."""

from pathlib import Path

import pytest

from app.services.hcl_parser import HCLVariable, extract_options_from_validation, parse_variables


# Path to real variables.tf for integration testing
REAL_VARIABLES_TF = (
    Path(__file__).resolve().parent.parent.parent.parent
    / "terraform"
    / "aws"
    / "existing_vpc_resources"
    / "variables.tf"
)


# ---------------------------------------------------------------------------
# Basic parsing tests
# ---------------------------------------------------------------------------


class TestParseSimpleVariable:
    def test_name_and_description(self):
        content = '''
variable "aws_region" {
  description = "The AWS region to use"
}
'''
        result = parse_variables(content)
        assert len(result) == 1
        assert result[0].name == "aws_region"
        assert result[0].description == "The AWS region to use"


class TestParseVariableWithType:
    def test_string_type(self):
        content = '''
variable "region" {
  description = "Region"
  type        = string
}
'''
        result = parse_variables(content)
        assert result[0].type == "string"

    def test_bool_type(self):
        content = '''
variable "enabled" {
  description = "Enable feature"
  type        = bool
}
'''
        result = parse_variables(content)
        assert result[0].type == "bool"

    def test_number_type(self):
        content = '''
variable "count" {
  description = "Count"
  type        = number
}
'''
        result = parse_variables(content)
        assert result[0].type == "number"

    def test_any_type(self):
        content = '''
variable "data" {
  description = "Arbitrary data"
  type        = any
}
'''
        result = parse_variables(content)
        assert result[0].type == "any"


# ---------------------------------------------------------------------------
# Default value tests
# ---------------------------------------------------------------------------


class TestParseVariableDefaults:
    def test_default_string(self):
        content = '''
variable "region" {
  description = "Region"
  type        = string
  default     = "us-west-2"
}
'''
        result = parse_variables(content)
        assert result[0].default == "us-west-2"

    def test_default_empty_string(self):
        content = '''
variable "name" {
  description = "Name"
  type        = string
  default     = ""
}
'''
        result = parse_variables(content)
        assert result[0].default == ""

    def test_default_bool_true(self):
        content = '''
variable "enabled" {
  description = "Enable"
  type        = bool
  default     = true
}
'''
        result = parse_variables(content)
        assert result[0].default == "true"

    def test_default_bool_false(self):
        content = '''
variable "disabled" {
  description = "Disable"
  type        = bool
  default     = false
}
'''
        result = parse_variables(content)
        assert result[0].default == "false"

    def test_default_number(self):
        content = '''
variable "port" {
  description = "Port"
  type        = number
  default     = 443
}
'''
        result = parse_variables(content)
        assert result[0].default == "443"

    def test_default_list(self):
        content = '''
variable "cidrs" {
  description = "CIDRs"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
'''
        result = parse_variables(content)
        assert result[0].default == '["0.0.0.0/0"]'

    def test_default_empty_list(self):
        content = '''
variable "items" {
  description = "Items"
  type        = list(string)
  default     = []
}
'''
        result = parse_variables(content)
        assert result[0].default == "[]"

    def test_default_map(self):
        content = '''
variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = { Name = "test" }
}
'''
        result = parse_variables(content)
        assert result[0].default is not None
        assert "Name" in result[0].default


# ---------------------------------------------------------------------------
# List type
# ---------------------------------------------------------------------------


class TestParseVariableWithListType:
    def test_list_string(self):
        content = '''
variable "cidrs" {
  description = "CIDRs"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
'''
        result = parse_variables(content)
        assert result[0].type == "list(string)"

    def test_set_number(self):
        content = '''
variable "ports" {
  description = "Ports"
  type        = set(number)
  default     = []
}
'''
        result = parse_variables(content)
        assert result[0].type == "set(number)"

    def test_map_string(self):
        content = '''
variable "labels" {
  description = "Labels"
  type        = map(string)
  default     = {}
}
'''
        result = parse_variables(content)
        assert result[0].type == "map(string)"


# ---------------------------------------------------------------------------
# Unquoted variable name
# ---------------------------------------------------------------------------


class TestParseVariableUnquotedName:
    def test_unquoted_name(self):
        content = '''
variable subnet_bits {
  description = "Number of bits in the network portion of the subnet CIDR"
}
'''
        result = parse_variables(content)
        assert len(result) == 1
        assert result[0].name == "subnet_bits"
        assert result[0].description == "Number of bits in the network portion of the subnet CIDR"


# ---------------------------------------------------------------------------
# Validation blocks
# ---------------------------------------------------------------------------


class TestParseVariableWithValidation:
    def test_single_validation(self):
        content = '''
variable "distributed_egress_vpc_count" {
  description = "Number of distributed egress VPCs to create (1-3)"
  type        = number
  default     = 1
  validation {
    condition     = var.distributed_egress_vpc_count >= 1 && var.distributed_egress_vpc_count <= 3
    error_message = "distributed_egress_vpc_count must be between 1 and 3"
  }
}
'''
        result = parse_variables(content)
        assert result[0].name == "distributed_egress_vpc_count"
        assert result[0].default == "1"
        assert result[0].validation is not None
        assert len(result[0].validation) == 1
        assert "var.distributed_egress_vpc_count >= 1" in result[0].validation[0]["condition"]
        assert result[0].validation[0]["error_message"] == "distributed_egress_vpc_count must be between 1 and 3"

    def test_contains_validation(self):
        content = '''
variable "license_type" {
  description = "License type"
  type        = string
  default     = "payg"
  validation {
    condition     = contains(["payg", "byol", "fortiflex"], var.license_type)
    error_message = "License type must be 'payg', 'byol', or 'fortiflex'."
  }
}
'''
        result = parse_variables(content)
        assert result[0].validation is not None
        assert 'contains(["payg", "byol", "fortiflex"]' in result[0].validation[0]["condition"]
        assert result[0].validation[0]["error_message"] == "License type must be 'payg', 'byol', or 'fortiflex'."

    def test_multiple_validations(self):
        content = '''
variable "threshold" {
  description = "Threshold"
  type        = number
  default     = 50
  validation {
    condition     = var.threshold >= 10
    error_message = "Must be at least 10."
  }
  validation {
    condition     = var.threshold <= 90
    error_message = "Must be at most 90."
  }
}
'''
        result = parse_variables(content)
        assert result[0].validation is not None
        assert len(result[0].validation) == 2
        assert "var.threshold >= 10" in result[0].validation[0]["condition"]
        assert "var.threshold <= 90" in result[0].validation[1]["condition"]


# ---------------------------------------------------------------------------
# Sensitive field
# ---------------------------------------------------------------------------


class TestParseSensitiveVariable:
    def test_sensitive_true(self):
        content = '''
variable "password" {
  description = "Admin password"
  type        = string
  sensitive   = true
}
'''
        result = parse_variables(content)
        assert result[0].sensitive is True

    def test_sensitive_false(self):
        content = '''
variable "name" {
  description = "Name"
  type        = string
  sensitive   = false
}
'''
        result = parse_variables(content)
        assert result[0].sensitive is False

    def test_no_sensitive_defaults_false(self):
        content = '''
variable "name" {
  description = "Name"
  type        = string
}
'''
        result = parse_variables(content)
        assert result[0].sensitive is False


# ---------------------------------------------------------------------------
# Multiple variables
# ---------------------------------------------------------------------------


class TestParseMultipleVariables:
    def test_multiple(self):
        content = '''
variable "region" {
  description = "Region"
  type        = string
  default     = "us-west-2"
}

variable "enabled" {
  description = "Enable"
  type        = bool
  default     = true
}

variable "count" {
  description = "Count"
  type        = number
  default     = 5
}
'''
        result = parse_variables(content)
        assert len(result) == 3
        assert result[0].name == "region"
        assert result[1].name == "enabled"
        assert result[2].name == "count"


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------


class TestParseEdgeCases:
    def test_no_variables(self):
        content = "# This file has no variables\n"
        result = parse_variables(content)
        assert result == []

    def test_empty_content(self):
        result = parse_variables("")
        assert result == []

    def test_comments_around_variables(self):
        content = '''
#====================================================================================================
# REGION SETTINGS
#====================================================================================================
variable "region" {
  description = "Region"
  type        = string
}
'''
        result = parse_variables(content)
        assert len(result) == 1
        assert result[0].name == "region"

    def test_variable_no_default_means_none(self):
        content = '''
variable "keypair" {
  description = "Keypair for instances"
}
'''
        result = parse_variables(content)
        assert result[0].default is None

    def test_variable_empty_default_means_empty(self):
        content = '''
variable "name" {
  description = "Name"
  type        = string
  default     = ""
}
'''
        result = parse_variables(content)
        assert result[0].default == ""
        assert result[0].default is not None


# ---------------------------------------------------------------------------
# extract_options_from_validation
# ---------------------------------------------------------------------------


class TestExtractOptions:
    def test_contains_pattern(self):
        var = HCLVariable(
            name="license_type",
            validation=[{
                "condition": 'contains(["payg", "byol", "fortiflex"], var.license_type)',
                "error_message": "Must be payg, byol, or fortiflex",
            }],
        )
        options = extract_options_from_validation(var)
        assert options == ["payg", "byol", "fortiflex"]

    def test_contains_two_options(self):
        var = HCLVariable(
            name="mode",
            validation=[{
                "condition": 'contains(["eip", "nat_gw"], var.mode)',
                "error_message": "Must be eip or nat_gw",
            }],
        )
        options = extract_options_from_validation(var)
        assert options == ["eip", "nat_gw"]

    def test_range_validation_returns_none(self):
        var = HCLVariable(
            name="count",
            validation=[{
                "condition": "var.count >= 1 && var.count <= 3",
                "error_message": "Must be between 1 and 3",
            }],
        )
        options = extract_options_from_validation(var)
        assert options is None

    def test_no_validation_returns_none(self):
        var = HCLVariable(name="name")
        options = extract_options_from_validation(var)
        assert options is None


# ---------------------------------------------------------------------------
# Integration test: real variables.tf
# ---------------------------------------------------------------------------


class TestParseRealVariablesTf:
    @pytest.fixture
    def real_content(self) -> str:
        """Read the actual existing_vpc_resources variables.tf."""
        assert REAL_VARIABLES_TF.exists(), f"Real variables.tf not found at {REAL_VARIABLES_TF}"
        return REAL_VARIABLES_TF.read_text()

    def test_parses_all_variables(self, real_content: str):
        """Should parse all ~50 variables from the real file."""
        result = parse_variables(real_content)
        # The file has about 50 variables; allow some flexibility for future changes
        assert len(result) >= 45, f"Expected at least 45 variables, got {len(result)}"

    def test_spot_check_aws_region(self, real_content: str):
        result = parse_variables(real_content)
        region_var = next(v for v in result if v.name == "aws_region")
        assert region_var.description == "The AWS region to use"
        assert region_var.default is None  # no default in this file

    def test_spot_check_management_cidr_sg(self, real_content: str):
        result = parse_variables(real_content)
        cidr_var = next(v for v in result if v.name == "management_cidr_sg")
        assert cidr_var.type == "list(string)"
        assert cidr_var.default == '["0.0.0.0/0"]'
        assert "CIDRs" in cidr_var.description

    def test_spot_check_enable_autoscale_deployment(self, real_content: str):
        result = parse_variables(real_content)
        var = next(v for v in result if v.name == "enable_autoscale_deployment")
        assert var.type == "bool"
        assert var.default == "true"

    def test_spot_check_unquoted_name(self, real_content: str):
        """The real file has `variable subnet_bits {` without quotes."""
        result = parse_variables(real_content)
        var = next(v for v in result if v.name == "subnet_bits")
        assert var.description == "Number of bits in the network portion of the subnet CIDR"

    def test_spot_check_number_default(self, real_content: str):
        result = parse_variables(real_content)
        var = next(v for v in result if v.name == "fortimanager_host_ip")
        assert var.type == "number"
        assert var.default == "14"

    def test_spot_check_validation(self, real_content: str):
        result = parse_variables(real_content)
        var = next(v for v in result if v.name == "distributed_egress_vpc_count")
        assert var.type == "number"
        assert var.default == "1"
        assert var.validation is not None
        assert len(var.validation) == 1
        assert "distributed_egress_vpc_count must be between 1 and 3" in var.validation[0]["error_message"]

    def test_spot_check_bool_false_default(self, real_content: str):
        result = parse_variables(real_content)
        var = next(v for v in result if v.name == "enable_fortimanager")
        assert var.type == "bool"
        assert var.default == "false"

    def test_spot_check_empty_string_default(self, real_content: str):
        result = parse_variables(real_content)
        var = next(v for v in result if v.name == "fortimanager_license_file")
        assert var.type == "string"
        assert var.default == ""

    def test_no_variable_has_none_name(self, real_content: str):
        result = parse_variables(real_content)
        for v in result:
            assert v.name, f"Found variable with empty name: {v}"


class TestParseAutoscaleVariablesTf:
    """Integration test against autoscale_template variables.tf."""

    AUTOSCALE_VARIABLES_TF = (
        Path(__file__).resolve().parent.parent.parent.parent
        / "terraform"
        / "aws"
        / "autoscale_template"
        / "variables.tf"
    )

    @pytest.fixture
    def real_content(self) -> str:
        assert self.AUTOSCALE_VARIABLES_TF.exists()
        return self.AUTOSCALE_VARIABLES_TF.read_text()

    def test_parses_all_variables(self, real_content: str):
        result = parse_variables(real_content)
        assert len(result) >= 30, f"Expected at least 30 variables, got {len(result)}"

    def test_contains_validation_extraction(self, real_content: str):
        """The autoscale file has contains() validations we can extract options from."""
        result = parse_variables(real_content)
        license_var = next(v for v in result if v.name == "autoscale_license_model")
        assert license_var.validation is not None
        options = extract_options_from_validation(license_var)
        assert options == ["hybrid", "byol", "on_demand"]

    def test_unquoted_fortiflex_vars(self, real_content: str):
        """The autoscale file has unquoted variable names like `variable fortiflex_sn_list`."""
        result = parse_variables(real_content)
        var = next(v for v in result if v.name == "fortiflex_sn_list")
        assert var.type == "list(string)"
        assert var.default == "[]"


class TestParseHaPairVariablesTf:
    """Integration test against ha_pair variables.tf."""

    HA_PAIR_VARIABLES_TF = (
        Path(__file__).resolve().parent.parent.parent.parent
        / "terraform"
        / "aws"
        / "ha_pair"
        / "variables.tf"
    )

    @pytest.fixture
    def real_content(self) -> str:
        assert self.HA_PAIR_VARIABLES_TF.exists()
        return self.HA_PAIR_VARIABLES_TF.read_text()

    def test_parses_all_variables(self, real_content: str):
        result = parse_variables(real_content)
        assert len(result) >= 20, f"Expected at least 20 variables, got {len(result)}"

    def test_sensitive_variable(self, real_content: str):
        result = parse_variables(real_content)
        pw_var = next(v for v in result if v.name == "fortigate_admin_password")
        assert pw_var.sensitive is True

    def test_contains_validation(self, real_content: str):
        result = parse_variables(real_content)
        var = next(v for v in result if v.name == "license_type")
        options = extract_options_from_validation(var)
        assert options == ["payg", "byol", "fortiflex"]

    def test_any_type(self, real_content: str):
        result = parse_variables(real_content)
        var = next(v for v in result if v.name == "fortigate_management_cidr")
        assert var.type == "any"
