"""Tests for the deterministic static-analysis layer of the forge-security-review skill.

Three groups:

1. Structural checks on the OpenGrep rule file that need no tooling (unique ids, allowed
   severities, metadata every rule must carry, skill_rule targets that exist, ASCII only).
2. Script checks (bash syntax, pinned checksums present for every platform, both scripts pin the
   same releases).
3. Fixture checks that run the wrapper with the OpenGrep layer against evals/fixtures and compare
   per-rule counts with evals/expected-results.json. These download the pinned OpenGrep binary on
   first use (about 47 MB) unless FORGE_SA_TESTS_OFFLINE=1 is set, in which case they are skipped
   when the binary is absent.

Run from the skill directory:  python -m unittest discover -s tests -v
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from collections import Counter
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
RULES_DIR = SKILL_DIR / "assets" / "opengrep-rules"
SECURITY_RULES_DIR = SKILL_DIR / "assets" / "security-rules"
SCRIPTS_DIR = SKILL_DIR / "scripts"
EVALS_DIR = SKILL_DIR / "evals"
FIXTURES_DIR = EVALS_DIR / "fixtures"
EXPECTED_FILE = EVALS_DIR / "expected-results.json"
SH_SCRIPT = SCRIPTS_DIR / "run_static_analysis.sh"
PS1_SCRIPT = SCRIPTS_DIR / "run_static_analysis.ps1"

RULE_FILES = sorted(RULES_DIR.glob("*.yaml"))
ALLOWED_SEVERITIES = {"ERROR", "WARNING"}
REQUIRED_METADATA = ("cwe", "confidence", "security-severity", "skill_rule")
ALLOWED_METADATA = {
    "cwe", "confidence", "security-severity", "skill_rule", "forge_surface",
    "upstream_overlap", "requires_manifest_correlation",
}


def rule_blocks(text):
    """Split a rule file into (rule_id, block_text) pairs without a YAML parser."""
    starts = [m.start() for m in re.finditer(r"^- id:\s*\S+", text, re.M)]
    blocks = []
    for i, start in enumerate(starts):
        end = starts[i + 1] if i + 1 < len(starts) else len(text)
        block = text[start:end]
        rule_id = re.match(r"- id:\s*(\S+)", block).group(1)
        blocks.append((rule_id, block))
    return blocks


class RuleFileStructureTests(unittest.TestCase):
    def test_rule_files_present(self):
        names = [p.name for p in RULE_FILES]
        self.assertEqual(names, ["forge-security-rules.yaml"])

    def test_rule_ids_are_unique(self):
        ids = []
        for path in RULE_FILES:
            ids.extend(rule_id for rule_id, _ in rule_blocks(path.read_text(encoding="utf-8")))
        duplicates = [rule_id for rule_id, n in Counter(ids).items() if n > 1]
        self.assertEqual(duplicates, [], f"duplicate rule ids: {duplicates}")
        self.assertGreaterEqual(len(ids), 40)

    def test_rule_ids_are_forge_prefixed(self):
        for path in RULE_FILES:
            for rule_id, _ in rule_blocks(path.read_text(encoding="utf-8")):
                self.assertRegex(rule_id, r"^forge-[a-z0-9-]+$", f"{path.name}: {rule_id}")

    def test_every_rule_has_allowed_severity(self):
        for path in RULE_FILES:
            for rule_id, block in rule_blocks(path.read_text(encoding="utf-8")):
                m = re.search(r"^  severity:\s*(\S+)", block, re.M)
                self.assertIsNotNone(m, f"{rule_id}: no severity")
                self.assertIn(m.group(1), ALLOWED_SEVERITIES, f"{rule_id}: severity {m.group(1)}")

    def test_every_rule_has_required_metadata(self):
        for path in RULE_FILES:
            for rule_id, block in rule_blocks(path.read_text(encoding="utf-8")):
                for key in REQUIRED_METADATA:
                    self.assertIsNotNone(re.search(rf"^    {re.escape(key)}:", block, re.M), f"{rule_id}: missing metadata.{key}")
                m = re.search(r"^  metadata:\n((?:    .*\n|\n)+)", block, re.M)
                keys = set(re.findall(r"^    ([A-Za-z_-]+):", m.group(1), re.M)) if m else set()
                self.assertEqual(keys - ALLOWED_METADATA, set(), f"{rule_id}: unexpected metadata keys")

    def test_skill_rule_targets_exist(self):
        for path in RULE_FILES:
            for rule_id, block in rule_blocks(path.read_text(encoding="utf-8")):
                m = re.search(r'^    skill_rule:\s*"assets/security-rules/([^"]+)"', block, re.M)
                self.assertIsNotNone(m, f"{rule_id}: skill_rule must point under assets/security-rules/")
                self.assertTrue((SECURITY_RULES_DIR / m.group(1)).is_file(), f"{rule_id}: skill_rule target missing: {m.group(1)}")

    def test_rule_files_are_ascii(self):
        for path in RULE_FILES:
            text = path.read_text(encoding="utf-8")
            bad = sorted({c for c in text if ord(c) > 127})
            self.assertEqual(bad, [], f"{path.name}: non-ASCII characters {bad}")

    def test_rules_exclude_dependencies_and_tests_per_extension(self):
        # OpenGrep 1.16.2 does not expand brace globs, so excludes must be spelled per extension.
        for path in RULE_FILES:
            code = "\n".join(l for l in path.read_text(encoding="utf-8").splitlines() if not l.lstrip().startswith("#"))
            self.assertNotIn("{js,ts", code, f"{path.name}: brace glob in paths.exclude is not expanded by OpenGrep")


class ScriptTests(unittest.TestCase):
    def test_bash_syntax(self):
        bash = shutil.which("bash")
        if not bash:
            self.skipTest("bash not available")
        subprocess.run([bash, "-n", str(SH_SCRIPT)], check=True)

    def test_powershell_param_block_is_first_statement(self):
        text = PS1_SCRIPT.read_text(encoding="utf-8")
        body = re.sub(r"<#.*?#>", "", text, flags=re.S)
        statements = [l for l in body.splitlines() if l.strip() and not l.strip().startswith("#")]
        self.assertTrue(statements[0].startswith("param("), f"first statement is {statements[0]!r}")

    def test_pins_are_consistent_between_scripts(self):
        sh = SH_SCRIPT.read_text(encoding="utf-8")
        ps1 = PS1_SCRIPT.read_text(encoding="utf-8")
        sh_tag = re.search(r"^FSRT_RELEASE_TAG='([^']+)'", sh, re.M).group(1)
        ps1_tag = re.search(r"^\$FsrtReleaseTag = '([^']+)'", ps1, re.M).group(1)
        self.assertEqual(sh_tag, ps1_tag)
        sh_ver = re.search(r"^OPENGREP_VERSION='([^']+)'", sh, re.M).group(1)
        ps1_ver = re.search(r"^\$OpenGrepVersion = '([^']+)'", ps1, re.M).group(1)
        self.assertEqual(sh_ver, ps1_ver)
        sh_win_fsrt = re.search(r"^FSRT_SHA256_x86_64_pc_windows_msvc='([0-9a-f]{64})'", sh, re.M).group(1)
        ps1_fsrt = re.search(r"^\$FsrtSha256 = '([0-9A-Fa-f]{64})'", ps1, re.M).group(1)
        self.assertEqual(sh_win_fsrt.lower(), ps1_fsrt.lower())
        sh_win_og = re.search(r"^OPENGREP_SHA256_windows_x86='([0-9a-f]{64})'", sh, re.M).group(1)
        ps1_og = re.search(r"^\$OpenGrepSha256 = '([0-9A-Fa-f]{64})'", ps1, re.M).group(1)
        self.assertEqual(sh_win_og.lower(), ps1_og.lower())

    def test_every_platform_has_a_checksum(self):
        sh = SH_SCRIPT.read_text(encoding="utf-8")
        for var in (
            "FSRT_SHA256_aarch64_apple_darwin",
            "FSRT_SHA256_aarch64_unknown_linux_gnu",
            "FSRT_SHA256_x86_64_unknown_linux_gnu",
            "FSRT_SHA256_x86_64_pc_windows_msvc",
            "OPENGREP_SHA256_osx_arm64",
            "OPENGREP_SHA256_osx_x86",
            "OPENGREP_SHA256_manylinux_x86",
            "OPENGREP_SHA256_manylinux_aarch64",
            "OPENGREP_SHA256_musllinux_x86",
            "OPENGREP_SHA256_musllinux_aarch64",
            "OPENGREP_SHA256_windows_x86",
        ):
            self.assertIsNotNone(re.search(rf"^{var}='[0-9a-f]{{64}}'", sh, re.M), f"{var} missing or malformed")

    def test_gitignore_covers_downloaded_binaries(self):
        ignored = (SCRIPTS_DIR / ".gitignore").read_text(encoding="utf-8").split()
        for name in ("fsrt", "fsrt.exe", "opengrep", "opengrep.exe"):
            self.assertIn(name, ignored)


def wrapper_available():
    """True when the wrapper can run the OpenGrep layer here (binary present or download allowed)."""
    if os.name == "nt" or not shutil.which("bash"):
        return False
    if os.environ.get("FORGE_SA_TESTS_OFFLINE") == "1" and not (SCRIPTS_DIR / "opengrep").exists():
        return False
    return True


def run_opengrep_layer(fixture_dir, output_dir):
    env = dict(os.environ, FORGE_SA_SKIP_FSRT="1", FORGE_SA_OUTPUT_DIR=str(output_dir))
    proc = subprocess.run(["bash", str(SH_SCRIPT), str(fixture_dir)], env=env, capture_output=True, text=True)
    return proc


def counts_from_results(results_path):
    data = json.loads(Path(results_path).read_text(encoding="utf-8"))
    counter = Counter(r["check_id"].rsplit(".", 1)[-1] for r in data["results"])
    return dict(sorted(counter.items())), data


@unittest.skipUnless(wrapper_available(), "wrapper cannot run here (Windows, no bash, or offline without a binary)")
class FixtureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.expected = json.loads(EXPECTED_FILE.read_text(encoding="utf-8"))
        cls.tmp = Path(tempfile.mkdtemp(prefix="forge-sa-tests-"))

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def run_fixture(self, name):
        fixture_dir = FIXTURES_DIR / name
        self.assertTrue((fixture_dir / "manifest.yml").is_file(), f"{name}: fixture has no manifest.yml")
        out = self.tmp / name.replace("/", "_")
        proc = run_opengrep_layer(fixture_dir, out)
        self.assertEqual(proc.returncode, 0, f"{name}: wrapper exit {proc.returncode}\n{proc.stdout}\n{proc.stderr}")
        summary = json.loads((out / "static-analysis-summary.json").read_text(encoding="utf-8"))
        self.assertEqual(summary["tools"]["opengrep"]["status"], "completed", summary)
        self.assertEqual(summary["tools"]["fsrt"]["status"], "skipped", summary)
        self.assertTrue((out / "opengrep" / "results.sarif").is_file(), f"{name}: no SARIF output")
        counts, data = counts_from_results(out / "opengrep" / "results.json")
        self.assertEqual(data.get("errors", []), [], f"{name}: OpenGrep reported file errors")
        self.assertEqual(summary["tools"]["opengrep"]["findings"], len(data["results"]))
        return counts

    def test_expected_results_cover_every_fixture(self):
        fixtures = sorted(str(p.relative_to(FIXTURES_DIR)) for p in FIXTURES_DIR.glob("*/*") if (p / "manifest.yml").is_file())
        self.assertEqual(fixtures, sorted(self.expected.keys()))

    def test_vulnerable_fixtures_match_expected_counts_and_cover_every_rule(self):
        seen = set()
        for name in ("core/vulnerable", "extended/vulnerable"):
            counts = self.run_fixture(name)
            self.assertEqual(counts, self.expected[name])
            seen |= set(counts)
        all_ids = set()
        for path in RULE_FILES:
            all_ids |= {rule_id for rule_id, _ in rule_blocks(path.read_text(encoding="utf-8"))}
        self.assertEqual(sorted(all_ids - seen), [], "rules that do not fire on any vulnerable fixture")

    def test_safe_twins_are_silent(self):
        for name in ("core/safe", "extended/safe"):
            counts = self.run_fixture(name)
            self.assertEqual(counts, {}, f"findings on {name}: {counts}")

    def test_wrapper_rejects_a_directory_without_a_manifest(self):
        proc = run_opengrep_layer(self.tmp, self.tmp / "no-manifest")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("manifest.yml", proc.stderr)

    def test_wrapper_reports_incomplete_when_a_tool_cannot_run(self):
        # Point the wrapper at an empty rules directory through a copy of the scripts folder so the
        # OpenGrep layer cannot run; the summary must say not_run and the exit code must be 1.
        skill_copy = self.tmp / "skill-copy"
        shutil.copytree(SKILL_DIR / "scripts", skill_copy / "scripts", ignore=shutil.ignore_patterns("fsrt", "fsrt.exe"))
        (skill_copy / "assets" / "opengrep-rules").mkdir(parents=True)
        env = dict(os.environ, FORGE_SA_SKIP_FSRT="1", FORGE_SA_OUTPUT_DIR=str(self.tmp / "incomplete"))
        proc = subprocess.run(["bash", str(skill_copy / "scripts" / "run_static_analysis.sh"), str(FIXTURES_DIR / "core/safe")], env=env, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 1, proc.stdout + proc.stderr)
        summary = json.loads((self.tmp / "incomplete" / "static-analysis-summary.json").read_text(encoding="utf-8"))
        self.assertEqual(summary["overall"], "incomplete")
        self.assertEqual(summary["tools"]["opengrep"]["status"], "not_run")
        self.assertIn("INCOMPLETE", proc.stderr)


if __name__ == "__main__":
    unittest.main()
