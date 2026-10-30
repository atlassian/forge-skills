"""Tests for scripts/analyze_display_conditions.py"""
import json
import unittest
from io import StringIO
from itertools import product
from unittest.mock import patch

from scripts import analyze_display_conditions as dc


ADMIN = {"hasGlobalPermission": "ADMINISTER"}
CREATE = {"hasGlobalPermission": "CREATE_PROJECT"}
LOGGED_IN = {"isLoggedIn": True}
SITE_ADMIN = {"isSiteAdmin": True}
LEGACY = {"or": {**ADMIN, "or": CREATE}}
ARRAY = {"or": [ADMIN, CREATE]}
MANIFEST = """modules:
  jira:issuePanel:
    - key: test-panel
      displayConditions:
        or:
          hasGlobalPermission: ADMINISTER
          or:
            hasGlobalPermission: CREATE_PROJECT
"""


class TestAnalyzeCondition(unittest.TestCase):

    def test_flattens_nested_or(self):
        result = dc.analyze_condition(LEGACY)
        self.assertEqual(result["status"], "suggestion")
        self.assertEqual(result["after"], ARRAY)
        self.assertEqual(result["equivalence"]["assignments_checked"], 4)

    def test_flattens_nested_and(self):
        result = dc.analyze_condition({"and": {**ADMIN, "and": CREATE}})
        self.assertEqual(result["after"], {"and": [ADMIN, CREATE]})

    def test_preserves_separate_and_branches(self):
        before = {"or": {
            "and": {**ADMIN, "and": CREATE},
            "not": {"not": {"and": {**LOGGED_IN, **SITE_ADMIN}}},
        }}
        result = dc.analyze_condition(before)
        self.assertEqual(result["after"], {
            "or": [{"and": [ADMIN, CREATE]}, {"and": [LOGGED_IN, SITE_ADMIN]}],
        })
        self.assertEqual(result["equivalence"]["assignments_checked"], 16)

    def test_double_negation_preserves_implicit_or(self):
        before = {"not": {"not": {**LOGGED_IN, **SITE_ADMIN}}}
        self.assertEqual(dc.analyze_condition(before)["after"], {
            "or": [LOGGED_IN, SITE_ADMIN],
        })
        self.assertFalse(dc.verify_equivalent(before, {**LOGGED_IN, **SITE_ADMIN})[0])

    def test_documented_not_means_none_of_the_children(self):
        # https://developer.atlassian.com/platform/forge/manifest-reference/display-conditions/#operators
        # "not: none of the child conditions are true"; oracle is not rewriter output.
        cases = [(False, False, True), (False, True, False),
                 (True, False, False), (True, True, False)]
        for logged_in, admin, expected in cases:
            values = {dc.atom_id("isLoggedIn", True): logged_in,
                      dc.atom_id("isSiteAdmin", True): admin}
            for node in ({"not": {**LOGGED_IN, **SITE_ADMIN}}, {"not": [LOGGED_IN, SITE_ADMIN]}):
                self.assertEqual(dc.evaluate(node, values), expected)
        result = dc.analyze_condition({"not": {"or": {**ADMIN, "or": CREATE}}})
        self.assertEqual(result["after"], {"not": [ADMIN, CREATE]})

    def test_documented_comment_permission_example(self):
        # Exact displayConditions from #example; its prose says delete OR (TEST AND NOT Epic).
        node = {"or": {"canDeleteAllComments": True,
                       "and": {"projectKey": "TEST", "not": {"issueType": "Epic"}}}}
        for delete, project, epic in product((False, True), repeat=3):
            values = {dc.atom_id("canDeleteAllComments", True): delete,
                      dc.atom_id("projectKey", "TEST"): project,
                      dc.atom_id("issueType", "Epic"): epic}
            self.assertEqual(dc.evaluate(node, values), delete or (project and not epic))

    def test_documented_repeated_property_groups_example(self):
        # Same official page, "Use the same condition more than once": both a/b OR both c/d.
        leaves = [{"entityPropertyExists": {"entity": "user", "propertyKey": key}} for key in "abcd"]
        node = {"or": [{"and": leaves[:2]}, {"and": leaves[2:]}]}
        for a, b, c, d in product((False, True), repeat=4):
            values = {dc.atom_id("entityPropertyExists", leaf["entityPropertyExists"]): value
                      for leaf, value in zip(leaves, (a, b, c, d))}
            self.assertEqual(dc.evaluate(node, values), (a and b) or (c and d))

    def test_root_key_collision_keeps_both_groups_in_an_array(self):
        before = {"and": [{"or": {**ADMIN, "or": CREATE}},
                          {"or": {**LOGGED_IN, "or": SITE_ADMIN}}]}
        result = dc.analyze_condition(before)
        self.assertEqual(result["after"], {
            "and": [{"or": [ADMIN, CREATE]}, {"or": [LOGGED_IN, SITE_ADMIN]}],
        })
        self.assertEqual(result["equivalence"]["assignments_checked"], 16)

    def test_preserves_opaque_predicates_and_yaml_types(self):
        expression = {"jiraExpression": "user != null && issue.properties['or'] == true"}
        property_check = {"entityPropertyContainsAll": {
            "entity": "user", "propertyKey": "preferences",
            "objectName": "filters.and",
            "value": ["yes", "no", "on", "off", "y", "n", "false", "1e3", "012", "0o12",
                      "2026-10-30", "2026-10-30T10:00:00Z"],
        }}
        before = {"or": {**expression, "or": property_check}}
        result = dc.analyze_condition(before)
        expected = {"or": [expression, property_check]}
        self.assertEqual(result["after"], expected)
        self.assertEqual(dc.yaml.load(result["after_yaml"], Loader=dc.ConditionLoader)["displayConditions"], expected)
        self.assertEqual(dc.yaml.safe_load(result["after_yaml"])["displayConditions"], expected)
        for value in property_check["entityPropertyContainsAll"]["value"]:
            self.assertIn(f"'{value}'", result["after_yaml"])

    def test_leaves_readable_expressions_unchanged(self):
        for condition in (LOGGED_IN, {**LOGGED_IN, **SITE_ADMIN}, ARRAY):
            with self.subTest(condition=condition):
                self.assertEqual(dc.analyze_condition(condition)["status"], "no-change")

    @patch("scripts.analyze_display_conditions.render", return_value={"and": [ADMIN, CREATE]})
    def test_rejects_a_non_equivalent_candidate(self, mock_render):
        result = dc.analyze_condition(LEGACY)
        self.assertEqual(result["status"], "skipped")
        self.assertNotIn("after", result)

    def test_reports_malformed_operator(self):
        result = dc.analyze_condition({"or": "not-a-condition"})
        self.assertEqual(result["status"], "error")
        self.assertNotIn("after", result)

    def test_skips_expressions_over_verification_limit(self):
        condition = {"or": [{"projectKey": str(i)} for i in range(dc.MAX_PREDICATES + 1)]}
        result = dc.analyze_condition(condition)
        self.assertEqual(result["status"], "skipped")
        self.assertNotIn("after", result)


class TestConditionYaml(unittest.TestCase):

    def test_rejects_duplicate_condition_keys(self):
        with self.assertRaisesRegex(dc.AnalysisError, "Duplicate YAML key"):
            dc.yaml.load("isLoggedIn: true\nisLoggedIn: false\n", Loader=dc.ConditionLoader)

    def test_skips_unsupported_condition_yaml(self):
        for text in ("x: &shared {}\ny: *shared", "x: {<<: {a: 1}}", "x: !custom value"):
            with self.subTest(text=text), self.assertRaises(dc.UnsupportedInput):
                dc.yaml.load(text, Loader=dc.ConditionLoader)


class TestAnalyzeFile(unittest.TestCase):

    @patch("scripts.analyze_display_conditions.Path.stat")
    @patch("scripts.analyze_display_conditions.Path.read_text")
    def test_reports_module_location_and_product_scope(self, mock_read, mock_stat):
        mock_stat.return_value.st_size = len(MANIFEST)
        cases = [
            ("jira:issuePanel", "suggestion"),
            ("jiraServiceManagement:portalRequestDetail", "suggestion"),
            ("confluence:contentBylineItem", "skipped"),
        ]
        for module_type, status in cases:
            with self.subTest(module_type=module_type):
                mock_read.return_value = MANIFEST.replace("jira:issuePanel", module_type)
                finding = dc.analyze_file("manifest.yml")["findings"][0]
                self.assertEqual(finding["status"], status)
                self.assertEqual(finding["module_key"], "test-panel")
                self.assertEqual(finding["line"], 4)
                self.assertEqual(finding["location"], ["modules", module_type, 0, "displayConditions"])

    @patch("scripts.analyze_display_conditions.Path.stat")
    @patch("scripts.analyze_display_conditions.Path.read_text")
    def test_nested_pages_and_sections_in_page_modules(self, mock_read, mock_stat):
        text = """modules:
  PAGE_MODULE:
    - key: main-page
      pages:
        - title: Direct page
          displayConditions: {or: {hasGlobalPermission: ADMINISTER, or: {hasGlobalPermission: CREATE_PROJECT}}}
      sections:
        - header: Section
          displayConditions: {or: {hasGlobalPermission: ADMINISTER, or: {hasGlobalPermission: CREATE_PROJECT}}}
          pages:
            - title: Nested page
              displayConditions: {or: {hasGlobalPermission: ADMINISTER, or: {hasGlobalPermission: CREATE_PROJECT}}}
"""
        mock_stat.return_value.st_size = len(text)
        for module in ("jira:adminPage", "jira:globalPage", "jira:projectPage", "jira:projectSettingsPage"):
            with self.subTest(module=module):
                mock_read.return_value = text.replace("PAGE_MODULE", module)
                findings = dc.analyze_file("manifest.yml")["findings"]
                self.assertEqual([f["status"] for f in findings], ["suggestion"] * 3)
                self.assertEqual([f["location"][3:] for f in findings], [
                    ["pages", 0, "displayConditions"], ["sections", 0, "displayConditions"],
                    ["sections", 0, "pages", 0, "displayConditions"],
                ])
                self.assertEqual([f["line"] for f in findings], [6, 9, 12])

    @patch("scripts.analyze_display_conditions.Path.stat")
    @patch("scripts.analyze_display_conditions.Path.read_text")
    def test_mixed_product_manifest(self, mock_read, mock_stat):
        entries = MANIFEST.split("modules:\n", 1)[1]
        mock_read.return_value = "modules:\n" + entries + entries.replace(
            "jira:issuePanel", "jiraServiceManagement:portalRequestDetail"
        ) + entries.replace("jira:issuePanel", "confluence:contentBylineItem")
        mock_stat.return_value.st_size = len(mock_read.return_value)
        findings = dc.analyze_file("manifest.yml")["findings"]
        self.assertEqual([f["status"] for f in findings], ["suggestion", "suggestion", "skipped"])
        self.assertNotIn("after", findings[2])

    @patch("scripts.analyze_display_conditions.Path.stat")
    @patch("scripts.analyze_display_conditions.Path.read_text")
    def test_ignores_unrelated_values_but_isolates_unsupported_conditions(self, mock_read, mock_stat):
        # None of this non-condition data should be constructed or schema-validated.
        mock_read.return_value = """app:
  metadata: !custom value
  settings: {duplicate: first, duplicate: second}
  shared: &shared {a: 1}
  reuse: *shared
  nonstring: {1: value}
""" + MANIFEST + """    - key: unsupported-panel
      displayConditions: &conditions {isLoggedIn: true}
  function: not-a-module-list
"""
        mock_stat.return_value.st_size = len(mock_read.return_value)
        result = dc.analyze_file("manifest.yml")
        self.assertEqual(result["status"], "analyzed")
        self.assertEqual([f["status"] for f in result["findings"]], ["suggestion", "skipped"])
        self.assertEqual(result["findings"][0]["after"], ARRAY)
        self.assertNotIn("after", result["findings"][1])

    @patch("scripts.analyze_display_conditions.Path.stat")
    @patch("scripts.analyze_display_conditions.Path.read_text", return_value="modules: [")
    def test_reports_invalid_yaml(self, mock_read, mock_stat):
        mock_stat.return_value.st_size = 10
        result = dc.analyze_file("manifest.yml")
        self.assertEqual(result["status"], "error")
        self.assertEqual(result["findings"], [])

    @patch("scripts.analyze_display_conditions.Path.stat", side_effect=OSError("Cannot read manifest"))
    def test_reports_unreadable_file(self, mock_stat):
        result = dc.analyze_file("manifest.yml")
        self.assertEqual(result["status"], "error")
        self.assertIn("Cannot read manifest", result["reason"])


class TestMain(unittest.TestCase):

    @patch("scripts.analyze_display_conditions.Path.write_text")
    @patch("scripts.analyze_display_conditions.Path.read_text", return_value=MANIFEST)
    @patch("scripts.analyze_display_conditions.Path.stat")
    def test_prints_single_manifest_json_without_writing(self, mock_stat, mock_read, mock_write):
        mock_stat.return_value.st_size = len(MANIFEST)
        with patch("sys.stdout", new_callable=StringIO) as output:
            code = dc.main(["manifest.yml"])
        report = json.loads(output.getvalue())
        self.assertEqual(code, 0)
        self.assertEqual(report["path"], "manifest.yml")
        self.assertEqual(report["status"], "analyzed")
        self.assertEqual(report["findings"][0]["after"], ARRAY)
        self.assertNotIn("files", report)
        self.assertNotIn("before_yaml", report["findings"][0])
        mock_write.assert_not_called()

    @patch("scripts.analyze_display_conditions.Path.read_text")
    @patch("scripts.analyze_display_conditions.Path.stat")
    def test_exit_codes_for_malformed_and_non_forge_manifests(self, mock_stat, mock_read):
        invalid_condition = MANIFEST.split("      displayConditions:")[0] + "      displayConditions: {or: invalid}\n"
        cases = [("modules: [", "error", 1), ("modules: []", "error", 1),
                 ("applications:\n  - name: cloud-foundry-app\n", "skipped", 0),
                 (invalid_condition, "analyzed", 1)]
        for text, status, expected_code in cases:
            with self.subTest(text=text):
                mock_read.return_value = text
                mock_stat.return_value.st_size = len(text)
                with patch("sys.stdout", new_callable=StringIO) as output:
                    code = dc.main(["manifest.yaml"])
                result = json.loads(output.getvalue())
                self.assertEqual(code, expected_code)
                self.assertEqual(result["status"], status)
                if status == "analyzed":
                    self.assertEqual(result["findings"][0]["status"], "error")
                else:
                    self.assertEqual(result["findings"], [])
                if status == "skipped":
                    self.assertIn("Not a Forge manifest", result["reason"])

    @patch("scripts.analyze_display_conditions.Path.read_text")
    @patch("scripts.analyze_display_conditions.Path.stat", side_effect=FileNotFoundError("Missing manifest"))
    def test_missing_file_and_directory_arguments_do_not_scan(self, mock_stat, mock_read):
        for path in ("missing/manifest.yml", "."):
            with self.subTest(path=path), patch("sys.stdout", new_callable=StringIO) as output:
                self.assertEqual(dc.main([path]), 1)
                self.assertEqual(json.loads(output.getvalue())["status"], "error")
        mock_read.assert_not_called()

    def test_requires_exactly_one_path_and_no_format_option(self):
        for args in ([], ["manifest.yml", "manifest.yaml"], ["manifest.yml", "--format", "json"]):
            with self.subTest(args=args), patch("sys.stderr", new_callable=StringIO), self.assertRaises(SystemExit) as error:
                dc.main(args)
            self.assertEqual(error.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
