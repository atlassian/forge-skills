// Forge Guru — generated during forge-onboarding.
// Attempts docs search and explicitly labels curated fallback links.
import api from '@forge/api';

export async function searchForgeDocs(payload) {
  const query = typeof payload?.query === 'string' ? payload.query.trim() : '';
  if (!query) {
    return { source: 'empty', results: [], note: 'No query provided. Ask a specific Forge question.' };
  }

  const url =
    'https://developer.atlassian.com/gateway/api/search/?' +
    `q=${encodeURIComponent(query)}&site=developer`;

  try {
    const response = await api.fetch(url);
    if (!response.ok) {
      return fallback(query, `Search returned HTTP ${response.status}.`);
    }
    const data = await response.json();
    const raw = Array.isArray(data?.results) ? data.results : [];
    const results = raw.flatMap((result) => {
      if (!result || typeof result !== 'object') return [];
      const link = result.url || result.link;
      if (typeof link !== 'string') return [];
      let parsed;
      try {
        parsed = new URL(link);
      } catch {
        return [];
      }
      if (parsed.origin !== 'https://developer.atlassian.com' || parsed.username || parsed.password) return [];
      return [{
        title: result.title || result.name || 'Untitled',
        url: parsed.href,
        snippet: result.snippet || result.description || ''
      }];
    }).slice(0, 3);

    if (results.length === 0) {
      return fallback(query, 'No usable matching docs found.');
    }
    return { query, source: 'search', results };
  } catch {
    // Avoid logging queries or remote response bodies.
    console.error('search-forge-docs: request or response processing failed');
    return fallback(query, 'Search request or response processing failed.');
  }
}

function fallback(query, note) {
  return {
    query,
    source: 'fallback',
    note: `${note} These are curated starting links, not live search matches.`,
    results: [
      {
        title: 'Forge documentation (home)',
        url: 'https://developer.atlassian.com/platform/forge/',
        snippet: 'Start here for the Forge platform documentation.'
      },
      {
        title: 'Forge manifest reference',
        url: 'https://developer.atlassian.com/platform/forge/manifest-reference/',
        snippet: 'Modules, permissions, and manifest properties.'
      },
      {
        title: 'Forge CLI reference',
        url: 'https://developer.atlassian.com/platform/forge/cli-reference/',
        snippet: 'Forge CLI commands and flags.'
      }
    ]
  };
}
