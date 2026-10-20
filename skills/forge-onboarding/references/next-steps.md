# Next steps — the rest of your Forge journey

Read when closing. Keep it short — the user just finished a successful build and does not
need a lecture. Never describe skipped or failed checks as successes.

## The Forge loop

> **Edit files → `forge deploy` → refresh the agent in the product.**
> That's the whole loop — everything else is variations on this.

If the user wants to tweak Guru's prompt or add a new conversation starter, point them at
`manifest.yml` and `src/index.js` in their app folder. A redeploy picks up the change
without needing to reinstall.

## Where to go from here

| Intent | Route |
| --- | --- |
| Add features or build another Forge app | `forge-app-builder` |
| Diagnose a failed deploy or runtime bug | `forge-debugger` |
| Pull external data into Rovo | `forge-connector` |
| Prepare for real users | `forge-app-review` (plus `forge-security-review` or `forge-cost-optimizer` as needed) |

[Build and launch your Forge app](https://developer.atlassian.com/platform/forge/build-and-launch-your-forge-app/)
is the wider map. [Forge Inspired](https://github.com/atlassian-labs/forge-inspired) has
example apps for inspiration.

## Lifetime

Guru remains available while the test site and app installation stay active. If the site
expires or is deleted, the app goes with it — it is not "forever".

Link the test site, the app folder, and
[Developer Console](https://developer.atlassian.com/console/myapps). Invite a next idea
if appropriate; no required "done" reply.
