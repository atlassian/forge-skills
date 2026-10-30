import React, { useEffect, useState } from 'react';
import { requestJira, view } from '@forge/bridge';
export default function App() {
  const [html, setHtml] = useState('');
  useEffect(() => {
    requestJira('/rest/api/3/issue/TEST-1').then(r => r.json()).then(d => setHtml(d.fields.description));
    view.getContext().then(ctx => { document.getElementById('x').innerHTML = ctx.extension.issue.summary; });
  }, []);
  return <div dangerouslySetInnerHTML={{ __html: html }} />;
}
