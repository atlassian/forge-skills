// Forge Guru — generated during forge-onboarding.
// Answers Forge developer questions by returning curated links to the official docs.
// The LLM uses these links as grounding for its response.

export async function searchForgeDocs(payload) {
  const query = typeof payload?.query === 'string' ? payload.query.trim() : '';
  if (!query) {
    return {
      query: '',
      results: [],
      note: 'No query provided. Ask a specific Forge question.',
    };
  }

  // Curated, topic-aware starting links. The LLM picks the most relevant based on query.
  const curated = pickLinks(query);

  return {
    query,
    results: curated,
    note: 'Use these official Forge documentation links as the source of truth when answering.',
  };
}

function pickLinks(query) {
  const q = query.toLowerCase();

  const all = [
    {
      title: 'Forge platform overview',
      url: 'https://developer.atlassian.com/platform/forge/',
      topics: ['forge', 'platform', 'overview', 'what is'],
    },
    {
      title: 'Manifest reference',
      url: 'https://developer.atlassian.com/platform/forge/manifest-reference/',
      topics: ['manifest', 'yaml', 'config', 'module', 'permission'],
    },
    {
      title: 'Modules index',
      url: 'https://developer.atlassian.com/platform/forge/manifest-reference/modules/',
      topics: ['module', 'extension', 'issue panel', 'macro', 'gadget', 'trigger'],
    },
    {
      title: 'Rovo Agent module',
      url: 'https://developer.atlassian.com/platform/forge/manifest-reference/modules/rovo-agent/',
      topics: ['rovo', 'agent', 'conversational', 'chat'],
    },
    {
      title: 'CLI reference',
      url: 'https://developer.atlassian.com/platform/forge/cli-reference/',
      topics: ['cli', 'command', 'deploy', 'install', 'create', 'lint'],
    },
    {
      title: 'Scopes and permissions',
      url: 'https://developer.atlassian.com/platform/forge/add-scopes-to-call-an-atlassian-rest-api/',
      topics: ['scope', 'permission', 'oauth', 'rest api', 'read', 'write'],
    },
    {
      title: 'Runtime fetch and egress',
      url: 'https://developer.atlassian.com/platform/forge/runtime-reference/fetch-api/',
      topics: ['fetch', 'http', 'egress', 'external', 'network'],
    },
    {
      title: 'Scheduled triggers',
      url: 'https://developer.atlassian.com/platform/forge/manifest-reference/modules/scheduled-trigger/',
      topics: ['schedule', 'cron', 'trigger', 'periodic'],
    },
    {
      title: 'Storage API',
      url: 'https://developer.atlassian.com/platform/forge/runtime-reference/storage-api/',
      topics: ['storage', 'persist', 'database', 'kv', 'save'],
    },
    {
      title: 'UI Kit',
      url: 'https://developer.atlassian.com/platform/forge/ui-kit/',
      topics: ['ui', 'component', 'frontend', 'react', 'ui kit'],
    },
  ];

  const scored = all
    .map((link) => ({
      ...link,
      score: link.topics.reduce((n, t) => (q.includes(t) ? n + 1 : n), 0),
    }))
    .sort((a, b) => b.score - a.score);

  // Always return the top 3; if nothing matched, the first three generic entries win.
  return scored.slice(0, 3).map(({ title, url }) => ({ title, url }));
}
