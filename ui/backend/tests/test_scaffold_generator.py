"""Tests for the skeleton tfvars.ui generator."""

from pathlib import Path

import pytest

from app.services.hcl_parser import HCLVariable, parse_variables
from app.services.scaffold_generator import (
    _empty_placeholder,
    _infer_ui_type,
    _name_to_label,
    generate_scaffold,
)
from app.services.tfvars_example_parser import TfvarsEntry, parse_tfvars_example


# ---------------------------------------------------------------------------
# _infer_ui_type tests
# ---------------------------------------------------------------------------

class TestInferUiType:
    def test_string(self):
        assert _infer_ui_type("string") == "text"

    def test_number(self):
        assert _infer_ui_type("number") == "number"

    def test_bool(self):
        assert _infer_ui_type("bool") == "checkbox"

    def test_list_string(self):
        assert _infer_ui_type("list(string)") == "list"

    def test_set_number(self):
        assert _infer_ui_type("set(number)") == "list"

    def test_map(self):
        assert _infer_ui_type("map(string)") == "text"

    def test_object(self):
        assert _infer_ui_type("object({name = string})") == "text"

    def test_empty_type(self):
        assert _infer_ui_type("") == "text"

    def test_unknown_type(self):
        assert _infer_ui_type("any") == "text"


# ---------------------------------------------------------------------------
# _name_to_label tests
# ---------------------------------------------------------------------------

class TestNameToLabel:
    def test_simple(self):
        assert _name_to_label("aws_region") == "Aws Region"

    def test_multi_word(self):
        assert _name_to_label("enable_jump_box_public_ip") == "Enable Jump Box Public Ip"

    def test_single_word(self):
        assert _name_to_label("keypair") == "Keypair"

    def test_abbreviations(self):
        assert _name_to_label("vpc_cidr_inspection") == "Vpc Cidr Inspection"


# ---------------------------------------------------------------------------
# _empty_placeholder tests
# ---------------------------------------------------------------------------

class TestEmptyPlaceholder:
    def test_string(self):
        assert _empty_placeholder("string") == '""'

    def test_bool(self):
        assert _empty_placeholder("bool") == "false"

    def test_number(self):
        assert _empty_placeholder("number") == "0"

    def test_list(self):
        assert _empty_placeholder("list(string)") == "[]"

    def test_set(self):
        assert _empty_placeholder("set(number)") == "[]"

    def test_map(self):
        assert _empty_placeholder("map(string)") == "{}"

    def test_object(self):
        assert _empty_placeholder("object({})") == "{}"

    def test_unknown(self):
        assert _empty_placeholder("") == '""'


# ---------------------------------------------------------------------------
# generate_scaffold — variables only (no example)
# ---------------------------------------------------------------------------

class TestScaffoldVariablesOnly:
    def test_single_string_variable(self):
        variables = [HCLVariable(name="aws_region", description="The AWS region", type="string")]
        result = generate_scaffold(variables)
        assert "# @ui-type: text" in result
        assert "# @ui-label: Aws Region" in result
        assert "# @ui-description: The AWS region" in result
        assert "# @ui-required: true" in result
        assert 'aws_region = ""' in result

    def test_bool_variable_with_default(self):
        variables = [HCLVariable(name="enable_tgw", description="Enable TGW", type="bool", default="true")]
        result = generate_scaffold(variables)
        assert "# @ui-type: checkbox" in result
        assert "# @ui-default: true" in result
        assert "enable_tgw = true" in result
        # Should NOT have @ui-required since it has a default
        assert "# @ui-required:" not in result

    def test_number_variable_with_default(self):
        variables = [HCLVariable(name="subnet_bits", description="Subnet bits", type="number", default="8")]
        result = generate_scaffold(variables)
        assert "# @ui-type: number" in result
        assert "# @ui-default: 8" in result
        assert "subnet_bits = 8" in result

    def test_list_variable(self):
        variables = [HCLVariable(name="cidrs", description="CIDR list", type="list(string)", default='["0.0.0.0/0"]')]
        result = generate_scaffold(variables)
        assert "# @ui-type: list" in result
        assert 'cidrs = ["0.0.0.0/0"]' in result

    def test_required_variable_no_default(self):
        variables = [HCLVariable(name="keypair", description="Key pair name", type="string")]
        result = generate_scaffold(variables)
        assert "# @ui-required: true" in result
        assert 'keypair = ""' in result

    def test_sensitive_variable_becomes_password(self):
        variables = [HCLVariable(name="admin_password", description="Admin pass", type="string", sensitive=True)]
        result = generate_scaffold(variables)
        assert "# @ui-type: password" in result

    def test_variable_with_validation_options(self):
        variables = [HCLVariable(
            name="mode",
            description="Firewall mode",
            type="string",
            default="1-arm",
            validation=[{"condition": 'contains(["1-arm", "2-arm"], var.mode)', "error_message": "Must be 1-arm or 2-arm"}],
        )]
        result = generate_scaffold(variables)
        assert "# @ui-options: 1-arm, 2-arm" in result

    def test_multiple_variables(self):
        variables = [
            HCLVariable(name="region", description="Region", type="string"),
            HCLVariable(name="count", description="Count", type="number", default="1"),
        ]
        result = generate_scaffold(variables)
        assert "region" in result
        assert "count" in result

    def test_empty_variables(self):
        assert generate_scaffold([]) == ""

    def test_no_description_omitted(self):
        variables = [HCLVariable(name="foo", type="string")]
        result = generate_scaffold(variables)
        assert "@ui-description" not in result


# ---------------------------------------------------------------------------
# generate_scaffold — with example entries
# ---------------------------------------------------------------------------

class TestScaffoldWithExample:
    def test_preserves_existing_annotations(self):
        variables = [HCLVariable(name="aws_region", description="The AWS region", type="string")]
        examples = [TfvarsEntry(
            name="aws_region",
            value='"us-west-1"',
            ui_annotations={"type": "select", "source": "static", "label": "AWS Region"},
        )]
        result = generate_scaffold(variables, examples)
        # Should use the example's annotations, not auto-generated
        assert "# @ui-type: select" in result
        assert "# @ui-source: static" in result
        assert "# @ui-label: AWS Region" in result

    def test_uses_example_value(self):
        variables = [HCLVariable(name="aws_region", description="Region", type="string")]
        examples = [TfvarsEntry(name="aws_region", value='"us-west-1"')]
        result = generate_scaffold(variables, examples)
        assert 'aws_region = "us-west-1"' in result

    def test_fills_missing_annotations(self):
        """Example has type but not label — label should be auto-generated."""
        variables = [HCLVariable(name="aws_region", description="The AWS region", type="string")]
        examples = [TfvarsEntry(name="aws_region", value='"us-west-1"', ui_annotations={"type": "select"})]
        result = generate_scaffold(variables, examples)
        assert "# @ui-type: select" in result
        assert "# @ui-label: Aws Region" in result
        assert "# @ui-description: The AWS region" in result

    def test_example_group_preserved(self):
        variables = [
            HCLVariable(name="region", description="Region", type="string"),
            HCLVariable(name="cp", description="Customer prefix", type="string"),
        ]
        examples = [
            TfvarsEntry(name="region", value='"us-west-1"', ui_annotations={"group": "Region Settings"}),
            TfvarsEntry(name="cp", value='"acme"', ui_annotations={"group": "Identification"}),
        ]
        result = generate_scaffold(variables, examples)
        assert "# @ui-group: Region Settings" in result
        assert "# @ui-group: Identification" in result

    def test_variable_not_in_example(self):
        """Variable exists in variables.tf but not in example — still generated."""
        variables = [
            HCLVariable(name="aws_region", description="Region", type="string"),
            HCLVariable(name="new_var", description="Brand new", type="number", default="42"),
        ]
        examples = [TfvarsEntry(name="aws_region", value='"us-west-1"')]
        result = generate_scaffold(variables, examples)
        assert "aws_region" in result
        assert "new_var" in result
        assert "new_var = 42" in result

    def test_preserves_show_if(self):
        variables = [HCLVariable(name="mgmt_cidr", type="string")]
        examples = [TfvarsEntry(
            name="mgmt_cidr",
            value='"10.0.0.0/16"',
            ui_annotations={"show-if": "enable_mgmt == true", "type": "text"},
        )]
        result = generate_scaffold(variables, examples)
        assert "# @ui-show-if: enable_mgmt == true" in result


# ---------------------------------------------------------------------------
# generate_scaffold — group headers
# ---------------------------------------------------------------------------

class TestScaffoldGroupHeaders:
    def test_group_header_emitted_once(self):
        variables = [
            HCLVariable(name="a", description="A", type="string"),
            HCLVariable(name="b", description="B", type="string"),
        ]
        examples = [
            TfvarsEntry(name="a", value='"x"', ui_annotations={"group": "Network"}),
            TfvarsEntry(name="b", value='"y"', ui_annotations={"group": "Network"}),
        ]
        result = generate_scaffold(variables, examples)
        assert result.count("# @ui-group: Network") == 1

    def test_multiple_groups(self):
        variables = [
            HCLVariable(name="a", description="A", type="string"),
            HCLVariable(name="b", description="B", type="string"),
            HCLVariable(name="c", description="C", type="string"),
        ]
        examples = [
            TfvarsEntry(name="a", value='"x"', ui_annotations={"group": "Network"}),
            TfvarsEntry(name="b", value='"y"', ui_annotations={"group": "Security"}),
            TfvarsEntry(name="c", value='"z"', ui_annotations={"group": "Security"}),
        ]
        result = generate_scaffold(variables, examples)
        assert result.count("# @ui-group: Network") == 1
        assert result.count("# @ui-group: Security") == 1
        # Network should come before Security
        assert result.index("# @ui-group: Network") < result.index("# @ui-group: Security")


# ---------------------------------------------------------------------------
# generate_scaffold — assignment value formatting
# ---------------------------------------------------------------------------

class TestScaffoldValues:
    def test_string_default_quoted(self):
        variables = [HCLVariable(name="x", type="string", default="hello")]
        result = generate_scaffold(variables)
        assert 'x = "hello"' in result

    def test_empty_string_default(self):
        variables = [HCLVariable(name="x", type="string", default="")]
        result = generate_scaffold(variables)
        assert 'x = ""' in result

    def test_bool_default(self):
        variables = [HCLVariable(name="x", type="bool", default="false")]
        result = generate_scaffold(variables)
        assert "x = false" in result

    def test_number_default(self):
        variables = [HCLVariable(name="x", type="number", default="42")]
        result = generate_scaffold(variables)
        assert "x = 42" in result

    def test_list_default(self):
        variables = [HCLVariable(name="x", type="list(string)", default='["a", "b"]')]
        result = generate_scaffold(variables)
        assert 'x = ["a", "b"]' in result


# ---------------------------------------------------------------------------
# Integration: real files
# ---------------------------------------------------------------------------

EXISTING_VPC_DIR = Path(__file__).parent.parent.parent.parent / "terraform" / "aws" / "existing_vpc_resources"


class TestScaffoldIntegration:
    @pytest.fixture
    def variables(self) -> list[HCLVariable]:
        content = (EXISTING_VPC_DIR / "variables.tf").read_text()
        return parse_variables(content)

    @pytest.fixture
    def examples(self) -> list[TfvarsEntry]:
        content = (EXISTING_VPC_DIR / "terraform.tfvars.example").read_text()
        return parse_tfvars_example(content)

    def test_generates_output(self, variables, examples):
        result = generate_scaffold(variables, examples)
        assert len(result) > 0

    def test_all_variables_present(self, variables, examples):
        result = generate_scaffold(variables, examples)
        for var in variables:
            assert f"{var.name} =" in result, f"Missing variable: {var.name}"

    def test_preserves_example_annotations(self, variables, examples):
        result = generate_scaffold(variables, examples)
        # aws_region should have its example annotations preserved
        assert "# @ui-source: static" in result
        assert "# @ui-label: AWS Region" in result

    def test_has_group_headers(self, variables, examples):
        result = generate_scaffold(variables, examples)
        assert "# @ui-group: Region and Availability Zones" in result
        assert "# @ui-group: Resource Identification" in result

    def test_variables_only_mode(self, variables):
        """Generate from variables.tf alone (no example file)."""
        result = generate_scaffold(variables)
        assert len(result) > 0
        for var in variables:
            assert f"{var.name} =" in result

    def test_output_is_parseable(self, variables, examples):
        """The generated scaffold should be parseable by the tfvars parser."""
        result = generate_scaffold(variables, examples)
        re_parsed = parse_tfvars_example(result)
        # Should have an entry for each variable
        re_parsed_names = {e.name for e in re_parsed}
        for var in variables:
            assert var.name in re_parsed_names, f"Re-parse missing: {var.name}"
