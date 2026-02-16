"""Tests for the terraform.tfvars.example parser."""

from pathlib import Path

import pytest

from app.services.tfvars_example_parser import TfvarsEntry, parse_tfvars_example


# Path to real terraform.tfvars.example for integration testing
REAL_TFVARS_EXAMPLE = (
    Path(__file__).resolve().parent.parent.parent.parent
    / "terraform"
    / "aws"
    / "existing_vpc_resources"
    / "terraform.tfvars.example"
)


# ---------------------------------------------------------------------------
# Basic assignment parsing
# ---------------------------------------------------------------------------


class TestParseSimpleAssignment:
    def test_single_assignment(self):
        content = 'name = "value"\n'
        result = parse_tfvars_example(content)
        assert len(result) == 1
        assert result[0].name == "name"
        assert result[0].value == '"value"'

    def test_no_comments(self):
        content = 'name = "value"\n'
        result = parse_tfvars_example(content)
        assert result[0].comments == []
        assert result[0].ui_annotations == {}


class TestParseStringValue:
    def test_preserves_quotes(self):
        content = 'aws_region = "us-west-1"\n'
        result = parse_tfvars_example(content)
        assert result[0].value == '"us-west-1"'

    def test_preserves_special_chars(self):
        content = 'management_cidr_sg = "x.x.x.x/32"\n'
        result = parse_tfvars_example(content)
        assert result[0].value == '"x.x.x.x/32"'

    def test_cidr_value(self):
        content = 'vpc_cidr = "192.168.0.0/16"\n'
        result = parse_tfvars_example(content)
        assert result[0].value == '"192.168.0.0/16"'


class TestParseNumberValue:
    def test_integer(self):
        content = "subnet_bits = 8\n"
        result = parse_tfvars_example(content)
        assert result[0].value == "8"

    def test_larger_number(self):
        content = "host_ip = 14\n"
        result = parse_tfvars_example(content)
        assert result[0].value == "14"


class TestParseBoolValue:
    def test_true(self):
        content = "enable_jump_box = true\n"
        result = parse_tfvars_example(content)
        assert result[0].value == "true"

    def test_false(self):
        content = "enable_distributed_egress_vpcs = false\n"
        result = parse_tfvars_example(content)
        assert result[0].value == "false"


class TestParseEmptyString:
    def test_empty_string(self):
        content = 'fortitester_admin_password = ""\n'
        result = parse_tfvars_example(content)
        assert result[0].value == '""'


class TestParseListValue:
    def test_simple_list(self):
        content = 'cidrs = ["0.0.0.0/0"]\n'
        result = parse_tfvars_example(content)
        assert result[0].value == '["0.0.0.0/0"]'

    def test_empty_list(self):
        content = "items = []\n"
        result = parse_tfvars_example(content)
        assert result[0].value == "[]"

    def test_multi_element_list(self):
        content = 'tags = ["a", "b", "c"]\n'
        result = parse_tfvars_example(content)
        assert result[0].value == '["a", "b", "c"]'


# ---------------------------------------------------------------------------
# Comment handling
# ---------------------------------------------------------------------------


class TestParseWithPlainComments:
    def test_captures_plain_comments(self):
        content = """\
# Hidden field - required by Terraform but same as vpc_cidr_inspection
vpc_cidr_ns_inspection = "10.0.0.0/16"
"""
        result = parse_tfvars_example(content)
        assert len(result) == 1
        assert result[0].comments == [
            "# Hidden field - required by Terraform but same as vpc_cidr_inspection"
        ]

    def test_multiple_plain_comments(self):
        content = """\
# Full path to FortiManager BYOL license file
# IMPORTANT: Do NOT place in the same directory as FortiGate autoscale licenses
# Leave empty ("") if using PAYG
fortimanager_license_file = "./licenses/fmgr_license.lic"
"""
        result = parse_tfvars_example(content)
        assert len(result[0].comments) == 3

    def test_separator_lines_are_comments(self):
        content = """\
#====================================================================================================
# SECTION TITLE
#====================================================================================================
some_var = "val"
"""
        result = parse_tfvars_example(content)
        assert len(result) == 1
        assert len(result[0].comments) == 3


# ---------------------------------------------------------------------------
# UI annotation extraction
# ---------------------------------------------------------------------------


class TestParseUiAnnotations:
    def test_extracts_type(self):
        content = """\
# @ui-type: select
aws_region = "us-west-1"
"""
        result = parse_tfvars_example(content)
        assert result[0].ui_annotations["type"] == "select"

    def test_extracts_label(self):
        content = """\
# @ui-label: AWS Region
aws_region = "us-west-1"
"""
        result = parse_tfvars_example(content)
        assert result[0].ui_annotations["label"] == "AWS Region"

    def test_extracts_multiple_annotations(self):
        content = """\
# @ui-type: select
# @ui-source: aws-keypairs
# @ui-label: EC2 Key Pair
# @ui-required: true
# @ui-width: half
keypair = ""
"""
        result = parse_tfvars_example(content)
        ann = result[0].ui_annotations
        assert ann["type"] == "select"
        assert ann["source"] == "aws-keypairs"
        assert ann["label"] == "EC2 Key Pair"
        assert ann["required"] == "true"
        assert ann["width"] == "half"

    def test_extracts_show_if(self):
        content = """\
# @ui-show-if: enable_autoscale_deployment == true
# @ui-compute: cidrsubnet(vpc_cidr_inspection, subnet_bits, 4)
inspection_az1_gwlb_subnet = ""
"""
        result = parse_tfvars_example(content)
        ann = result[0].ui_annotations
        assert ann["show-if"] == "enable_autoscale_deployment == true"
        assert ann["compute"] == "cidrsubnet(vpc_cidr_inspection, subnet_bits, 4)"

    def test_extracts_options_with_pipes(self):
        content = """\
# @ui-options: us-east-1|US East,us-west-1|US West
aws_region = "us-west-1"
"""
        result = parse_tfvars_example(content)
        assert result[0].ui_annotations["options"] == "us-east-1|US East,us-west-1|US West"

    def test_extracts_exclusive_with(self):
        content = """\
# @ui-exclusive-with: enable_ha_pair_deployment
enable_autoscale_deployment = true
"""
        result = parse_tfvars_example(content)
        assert result[0].ui_annotations["exclusive-with"] == "enable_ha_pair_deployment"

    def test_mixed_annotations_and_comments(self):
        content = """\
# @ui-type: select
# @ui-source: license-files
# @ui-label: License File
# Full path to FortiManager BYOL license file
# IMPORTANT: Do NOT place in the same directory
#
fortimanager_license_file = "./licenses/fmgr_license.lic"
"""
        result = parse_tfvars_example(content)
        assert result[0].ui_annotations["type"] == "select"
        assert result[0].ui_annotations["source"] == "license-files"
        assert result[0].ui_annotations["label"] == "License File"
        # Plain comments captured
        assert any("IMPORTANT" in c for c in result[0].comments)


# ---------------------------------------------------------------------------
# Group tracking
# ---------------------------------------------------------------------------


class TestParseGroupTracking:
    def test_group_assigned_to_variables(self):
        content = """\
# @ui-group: Region and Availability Zones
# @ui-order: 1

# @ui-type: select
# @ui-label: AWS Region
aws_region = "us-west-1"
"""
        result = parse_tfvars_example(content)
        assert result[0].ui_annotations["group"] == "Region and Availability Zones"

    def test_group_persists_across_variables(self):
        content = """\
# @ui-group: Security
# @ui-order: 4

# @ui-type: select
keypair = ""

# @ui-type: text
management_cidr_sg = "x.x.x.x/32"
"""
        result = parse_tfvars_example(content)
        assert result[0].ui_annotations["group"] == "Security"
        assert result[1].ui_annotations["group"] == "Security"


class TestParseGroupChanges:
    def test_group_changes_midfile(self):
        content = """\
# @ui-group: Region and Availability Zones
# @ui-order: 1

# @ui-type: select
aws_region = "us-west-1"

# @ui-group: Resource Identification
# @ui-order: 2

# @ui-type: text
cp = "acme"
"""
        result = parse_tfvars_example(content)
        assert len(result) == 2
        assert result[0].ui_annotations["group"] == "Region and Availability Zones"
        assert result[1].ui_annotations["group"] == "Resource Identification"

    def test_three_groups(self):
        content = """\
# @ui-group: Group A

# @ui-type: text
var_a = "a"

# @ui-group: Group B

# @ui-type: text
var_b = "b"

# @ui-group: Group C

# @ui-type: text
var_c = "c"
"""
        result = parse_tfvars_example(content)
        assert result[0].ui_annotations["group"] == "Group A"
        assert result[1].ui_annotations["group"] == "Group B"
        assert result[2].ui_annotations["group"] == "Group C"


# ---------------------------------------------------------------------------
# Hidden fields (no annotations)
# ---------------------------------------------------------------------------


class TestParseHiddenField:
    def test_hidden_field_no_annotations(self):
        content = """\
# Hidden field - supernet CIDR encompassing all spoke VPCs
vpc_cidr_spoke = "192.168.0.0/16"
"""
        result = parse_tfvars_example(content)
        assert len(result) == 1
        assert result[0].name == "vpc_cidr_spoke"
        assert result[0].value == '"192.168.0.0/16"'
        assert result[0].comments == [
            "# Hidden field - supernet CIDR encompassing all spoke VPCs"
        ]
        # No UI annotations (group may be set from context)
        assert "type" not in result[0].ui_annotations
        assert "label" not in result[0].ui_annotations

    def test_bare_assignment_no_comments(self):
        content = 'acl = "private"\n'
        result = parse_tfvars_example(content)
        assert len(result) == 1
        assert result[0].name == "acl"
        assert result[0].value == '"private"'
        assert result[0].comments == []
        assert result[0].ui_annotations == {}


# ---------------------------------------------------------------------------
# Multiple variables
# ---------------------------------------------------------------------------


class TestParseMultipleVariables:
    def test_returns_all(self):
        content = """\
aws_region = "us-west-1"

cp = "acme"

env = "test"
"""
        result = parse_tfvars_example(content)
        assert len(result) == 3
        assert result[0].name == "aws_region"
        assert result[1].name == "cp"
        assert result[2].name == "env"

    def test_consecutive_assignments(self):
        content = """\
var_a = "a"
var_b = "b"
var_c = "c"
"""
        result = parse_tfvars_example(content)
        assert len(result) == 3


# ---------------------------------------------------------------------------
# Empty and edge cases
# ---------------------------------------------------------------------------


class TestParseEmptyContent:
    def test_empty_string(self):
        result = parse_tfvars_example("")
        assert result == []


class TestParseCommentsOnly:
    def test_comments_no_assignments(self):
        content = """\
# This is just a comment file
#====================================================================================================
# SECTION TITLE
#====================================================================================================
#
# No actual variables here.
#
"""
        result = parse_tfvars_example(content)
        assert result == []


class TestParseInlineCommentIgnored:
    def test_inline_comment_stripped(self):
        content = 'aws_region = "us-west-1"  # some comment\n'
        result = parse_tfvars_example(content)
        assert result[0].value == '"us-west-1"'
        assert result[0].name == "aws_region"

    def test_number_with_inline_comment(self):
        content = "subnet_bits = 8  # bits for subnet calc\n"
        result = parse_tfvars_example(content)
        assert result[0].value == "8"

    def test_bool_with_inline_comment(self):
        content = "enabled = true  # enable the feature\n"
        result = parse_tfvars_example(content)
        assert result[0].value == "true"


# ---------------------------------------------------------------------------
# Whitespace variations
# ---------------------------------------------------------------------------


class TestWhitespaceVariations:
    def test_extra_spaces_around_equals(self):
        content = 'aws_region          = "us-west-1"\n'
        result = parse_tfvars_example(content)
        assert result[0].name == "aws_region"
        assert result[0].value == '"us-west-1"'

    def test_no_spaces_around_equals(self):
        content = 'name="value"\n'
        result = parse_tfvars_example(content)
        assert result[0].name == "name"
        assert result[0].value == '"value"'

    def test_trailing_whitespace(self):
        content = 'name = "value"   \n'
        result = parse_tfvars_example(content)
        assert result[0].value == '"value"'


# ---------------------------------------------------------------------------
# Collapsible and other advanced annotations
# ---------------------------------------------------------------------------


class TestAdvancedAnnotations:
    def test_collapsible_annotations(self):
        content = """\
# @ui-collapsible: true
# @ui-collapsed-default: true
# @ui-type: checkbox
enable_fortitester_1 = false
"""
        result = parse_tfvars_example(content)
        ann = result[0].ui_annotations
        assert ann["collapsible"] == "true"
        assert ann["collapsed-default"] == "true"
        assert ann["type"] == "checkbox"

    def test_depends_on_annotation(self):
        content = """\
# @ui-depends-on: aws_region
# @ui-type: select
keypair = ""
"""
        result = parse_tfvars_example(content)
        assert result[0].ui_annotations["depends-on"] == "aws_region"


# ---------------------------------------------------------------------------
# Integration test: real terraform.tfvars.example
# ---------------------------------------------------------------------------


class TestParseRealTfvarsExample:
    @pytest.fixture
    def real_content(self) -> str:
        """Read the actual existing_vpc_resources terraform.tfvars.example."""
        assert REAL_TFVARS_EXAMPLE.exists(), (
            f"Real terraform.tfvars.example not found at {REAL_TFVARS_EXAMPLE}"
        )
        return REAL_TFVARS_EXAMPLE.read_text()

    def test_parses_all_assignments(self, real_content: str):
        """Should parse all ~83 variable assignments from the real file."""
        result = parse_tfvars_example(real_content)
        # The file has 83 assignments; allow some flexibility for future changes
        assert len(result) >= 80, f"Expected at least 80 entries, got {len(result)}"
        assert len(result) <= 100, f"Expected at most 100 entries, got {len(result)}"

    def test_spot_check_aws_region(self, real_content: str):
        result = parse_tfvars_example(real_content)
        region = next(e for e in result if e.name == "aws_region")
        assert region.value == '"us-west-1"'
        assert region.ui_annotations["type"] == "select"
        assert region.ui_annotations["source"] == "static"
        assert region.ui_annotations["label"] == "AWS Region"
        assert region.ui_annotations["required"] == "true"
        assert region.ui_annotations["width"] == "full"
        assert region.ui_annotations["default"] == "us-west-1"
        assert region.ui_annotations["group"] == "Region and Availability Zones"

    def test_spot_check_subnet_bits(self, real_content: str):
        result = parse_tfvars_example(real_content)
        entry = next(e for e in result if e.name == "subnet_bits")
        assert entry.value == "8"
        assert entry.ui_annotations["type"] == "number"
        assert entry.ui_annotations["label"] == "Subnet Bits"

    def test_spot_check_enable_jump_box(self, real_content: str):
        result = parse_tfvars_example(real_content)
        entry = next(e for e in result if e.name == "enable_jump_box")
        assert entry.value == "true"
        assert entry.ui_annotations["type"] == "checkbox"
        assert entry.ui_annotations["group"] == "Jump Box"

    def test_spot_check_hidden_field(self, real_content: str):
        result = parse_tfvars_example(real_content)
        entry = next(e for e in result if e.name == "vpc_cidr_ns_inspection")
        assert entry.value == '"10.0.0.0/16"'
        # Hidden field has a plain comment but no @ui-type etc.
        assert "type" not in entry.ui_annotations
        assert "label" not in entry.ui_annotations
        assert any("Hidden field" in c for c in entry.comments)

    def test_spot_check_vpc_cidr_spoke(self, real_content: str):
        result = parse_tfvars_example(real_content)
        entry = next(e for e in result if e.name == "vpc_cidr_spoke")
        assert entry.value == '"192.168.0.0/16"'
        assert "type" not in entry.ui_annotations
        assert any("supernet" in c.lower() for c in entry.comments)

    def test_groups_tracked_correctly(self, real_content: str):
        result = parse_tfvars_example(real_content)

        # aws_region should be in "Region and Availability Zones"
        region = next(e for e in result if e.name == "aws_region")
        assert region.ui_annotations.get("group") == "Region and Availability Zones"

        # cp should be in "Resource Identification"
        cp = next(e for e in result if e.name == "cp")
        assert cp.ui_annotations.get("group") == "Resource Identification"

        # enable_fortimanager should be in "FortiManager"
        fmgr = next(e for e in result if e.name == "enable_fortimanager")
        assert fmgr.ui_annotations.get("group") == "FortiManager"

        # enable_distributed_egress_vpcs should be in "Distributed VPCs"
        dist = next(e for e in result if e.name == "enable_distributed_egress_vpcs")
        assert dist.ui_annotations.get("group") == "Distributed VPCs"

    def test_all_entries_have_names(self, real_content: str):
        result = parse_tfvars_example(real_content)
        for entry in result:
            assert entry.name, f"Found entry with empty name: {entry}"

    def test_no_duplicate_names(self, real_content: str):
        result = parse_tfvars_example(real_content)
        names = [e.name for e in result]
        assert len(names) == len(set(names)), (
            f"Found duplicate variable names: "
            f"{[n for n in names if names.count(n) > 1]}"
        )

    def test_spot_check_fortimanager_license_file(self, real_content: str):
        result = parse_tfvars_example(real_content)
        entry = next(e for e in result if e.name == "fortimanager_license_file")
        assert entry.value == '"./licenses/fmgr_license.lic"'
        assert entry.ui_annotations["type"] == "select"
        assert entry.ui_annotations["source"] == "license-files"

    def test_spot_check_acl_hidden(self, real_content: str):
        result = parse_tfvars_example(real_content)
        entry = next(e for e in result if e.name == "acl")
        assert entry.value == '"private"'
        assert any("Hidden field" in c for c in entry.comments)
