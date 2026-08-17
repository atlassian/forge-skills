import { test, expect } from "bun:test";
import { ForgeSkillsPlugin } from "./forge-skills.js";

test("registers the Forge and ADS MCP servers and the skills path", async () => {
  const hooks = await ForgeSkillsPlugin();
  const config = {};
  await hooks.config(config);

  expect(config.mcp.forge).toEqual({
    type: "remote",
    url: "https://mcp.atlassian.com/v1/forge/mcp",
    enabled: true,
  });
  expect(config.mcp["ads-mcp"].url).toBe("https://mcp.atlassian.com/v1/ads/public/mcp");
  expect(Array.isArray(config.skills.paths)).toBe(true);
  expect(config.skills.paths.some((p) => p.endsWith("/skills"))).toBe(true);
});

test("is idempotent across repeated config hooks", async () => {
  const hooks = await ForgeSkillsPlugin();
  const config = {};
  await hooks.config(config);
  await hooks.config(config);

  expect(Object.keys(config.mcp)).toHaveLength(2);
  expect(config.skills.paths.filter((p) => p.endsWith("/skills"))).toHaveLength(1);
});

test("never overwrites user-provided MCP or skills config", async () => {
  const hooks = await ForgeSkillsPlugin();
  const config = {
    mcp: { forge: { type: "remote", url: "https://example.test/custom", enabled: false } },
    skills: { paths: ["/custom/skills-root"] },
  };
  await hooks.config(config);

  expect(config.mcp.forge.url).toBe("https://example.test/custom");
  expect(config.mcp["ads-mcp"]).toBeDefined();
  expect(config.skills.paths).toContain("/custom/skills-root");
});
