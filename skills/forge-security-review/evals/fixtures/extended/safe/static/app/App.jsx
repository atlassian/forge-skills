import React, { useEffect, useState } from 'react';
import { requestJira, view, invoke } from '@forge/bridge';

// Product data is rendered through React's default escaping (no HTML sink at all);
// credentials returned by the backend are never written to the console.
export default function App() {
  const [summary, setSummary] = useState('');
  const [description, setDescription] = useState('');

  useEffect(() => {
    requestJira('/rest/api/3/issue/TEST-1')
      .then((r) => r.json())
      .then((d) => setDescription(d.fields.description));
    view.getContext().then((ctx) => setSummary(ctx.extension.issue.summary));
    invoke('getClientCredentials').then(({ expiresAt }) => console.log('credentials expire at', expiresAt));
  }, []);

  return (
    <div>
      <h1>{summary}</h1>
      <p>{description}</p>
    </div>
  );
}
