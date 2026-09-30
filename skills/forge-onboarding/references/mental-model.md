# What Forge is, and what we are building

Read only when the user wants introductory teaching. Keep this brief and invite questions
once; skip or shorten it when the user wants to build immediately.

Forge is Atlassian's app platform. Apps add product interfaces, run backend logic, call APIs,
and integrate services. Today's app is a Rovo Agent: a chat experience whose prompt can
direct it to call actions backed by our code.

| Building block | In this project |
| --- | --- |
| Manifest | `manifest.yml` declares the app, extension points, handlers, and permissions. |
| Module | `rovo:agent` makes an agent available; an `action` describes a callable operation. |
| Backend function | JavaScript hosted by Forge implements the action and returns data to Rovo. |

Permissions constrain backend access. An outbound fetch also needs its destination declared.
Keep the stock app's permissions as generated; Guru later adds only the host its code calls.

The wider platform includes Jira and Confluence extension points, product APIs, Rovo,
and Teamwork Graph integrations. Do not state that these capabilities are all available
or in Early Access as a group. For a specific feature, check its current lifecycle using
[Platform contract](platform-contract.md).

## Meet Forge Guru

First ship the stock Rovo template unchanged. Then customize its agent into Forge Guru,
for questions such as "Which module fits a Jira issue panel?" and "How do I call the Jira API?"
Its backend attempts a docs search and returns results for a cited answer. If search fails,
it reports that and supplies starting links. A citation still needs checking; do not promise
that an AI agent cannot invent details.

The same manifest/module/function concepts transfer to other Forge apps. Save the
message → action → function → response walkthrough until the user sees the stock action run.

Link [Forge's overview](https://developer.atlassian.com/platform/forge/) and
[Rovo modules](https://developer.atlassian.com/platform/forge/manifest-reference/modules/rovo-index/)
when relevant. Keep extra reading for questions or the closing handoff.
Continue to `scaffold` when ready; the user's earlier request to build Guru is enough.
