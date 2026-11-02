"""Tests for the repository's Codex marketplace packaging."""
import json
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[3]


class TestCodexMarketplace(unittest.TestCase):

    def test_marketplace_plugin_resolves_to_its_manifest(self):
        marketplace = json.loads(
            (REPO_ROOT / ".agents/plugins/marketplace.json").read_text()
        )
        for plugin in marketplace["plugins"]:
            with self.subTest(plugin=plugin["name"]):
                plugin_root = REPO_ROOT / plugin["source"]["path"]
                manifest_path = plugin_root / ".codex-plugin/plugin.json"
                self.assertTrue(
                    manifest_path.is_file(),
                    f"Marketplace source must contain a plugin manifest: {manifest_path}",
                )
                manifest = json.loads(manifest_path.read_text())
                self.assertEqual(manifest["name"], plugin["name"])


if __name__ == "__main__":
    unittest.main()
