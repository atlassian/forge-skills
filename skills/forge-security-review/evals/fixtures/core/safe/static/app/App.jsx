import React from 'react';
import DOMPurify from 'dompurify';
import { invoke } from '@forge/bridge';
export function announce() { window.parent.postMessage({ event: 'ready' }, 'https://example.atlassian.net'); }
export function load(el) { invoke('getText').then((text) => { if (typeof text === 'string' && text.length < 1000) el.textContent = text; }); }
export default function Page({ html }) { return <div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(html) }} />; }
