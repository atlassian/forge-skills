/**
 * Forge Skills — OpenCode plugin
 *
 * Registers the Atlassian Forge skill bundle and its MCP servers for OpenCode,
 * mirroring the per-host manifests in this repo (.claude-plugin/, .cursor-plugin/,
 * .codex-plugin/, gemini-extension.json).
 *
 * OpenCode loads this plugin via the repo's `opencode.json` (`plugin` array), so
 * opening this repo in OpenCode makes all six Forge skills and both MCP servers
 * available — no manual setup required.
 *
 * To use the skills from any other project, add this file to your global config
 * (~/.config/opencode/opencode.json):
 *
 *   {
 *     "$schema": "https://opencode.ai/config.json",
 *     "plugin": ["file:///ABSOLUTE/PATH/TO/forge-skills/.opencode-plugin/forge-skills.js"]
 *   }
 *
 * The skills path is resolved from this file's own location, so it keeps pointing
 * at this repo's `skills/` directory regardless of the working directory.
 *
 * @see https://opencode.ai/docs/plugins/
 * @see https://opencode.ai/docs/skills/
 * @see https://opencode.ai/docs/mcp-servers/
 */
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

// This file lives at <repo>/.opencode-plugin/forge-skills.js;
// the skill bundle lives at <repo>/skills (one level up).
const PLUGIN_DIR = dirname(fileURLToPath(import.meta.url));
const SKILLS_DIR = resolve(PLUGIN_DIR, "..", "skills");

// Remote MCP servers shared with the other hosts (see .mcp.json).
const MCP_SERVERS = {
  forge: {
    type: "remote",
    url: "https://mcp.atlassian.com/v1/forge/mcp",
    enabled: true,
  },
  "ads-mcp": {
    type: "remote",
    url: "https://mcp.atlassian.com/v1/ads/public/mcp",
    enabled: true,
  },
};

export const ForgeSkillsPlugin = async () => ({
  config: async (config) => {
    // Register the Forge + ADS MCP servers (idempotent: never overwrite user config).
    config.mcp ??= {};
    for (const [name, server] of Object.entries(MCP_SERVERS)) {
      if (!config.mcp[name]) config.mcp[name] = server;
    }

    // Make the bundled Forge skills (skills/<name>/SKILL.md) discoverable.
    config.skills ??= {};
    if (!Array.isArray(config.skills.paths)) config.skills.paths = [];
    if (!config.skills.paths.includes(SKILLS_DIR)) {
      config.skills.paths.push(SKILLS_DIR);
    }
  },
});
