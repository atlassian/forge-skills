import React from 'react';
import { invoke } from '@forge/bridge';
// forge-bridge-postmessage-wildcard-origin
export function announce(token) { window.parent.postMessage({ token }, "*"); }
// forge-bridge-invoke-then-html-sink
export function load(el) { invoke('getHtml').then((html) => { el.innerHTML = html; }); }
// forge-bridge-invoke-to-html-sink (await form)
export async function loadAwait(el) { const html = await invoke('getHtml'); el.innerHTML = html; }
// forge-unsafe-html-rendering (JSX form)
export default function Page({ html }) { return <div dangerouslySetInnerHTML={{ __html: html }} />; }
