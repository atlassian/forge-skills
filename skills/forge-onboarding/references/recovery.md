# Recover from an observed failure

Read only after a failure. Capture the command, target, exit result and relevant output
without credentials. Preserve partial files/registrations. Retry after a relevant change
or established transient cause, never in a blind loop.

| Evidence | Response | Resume point |
| --- | --- | --- |
| Node warning with successful command | Explain once and honor continuation; do not install tools merely to silence it. | Current phase |
| Executable missing or failing | Inspect error and [Setup](setup.md); repair what is necessary and authorized. | Failed check |
| Not authenticated | User runs interactive login; verify identity afterward. Never request a token. | Failed operation |
| Helper help fails | Resolve path/interpreter or missing sibling. Block automated scaffolding; a user-selected interactive handoff remains available. Never substitute agent-run raw creation. | Smoke test or user-run handoff |
| Terms/billing prompt | Stop input. User reviews interactively, or provides informed consent for a documented path. | Same operation after checking partial completion |
| Template rejected | Reconcile builder validation and official Rovo guidance; no blank/UI shortcut. | Creation after target recheck |
| Destination exists | Inspect for a resumable app; otherwise resolve a different target or exact authorized action. | Target selection |
| Partial scaffold after failure | Inspect files/app ID and registration outcome before creating again. Preserve files. | Verification or creation based on evidence |
| Provisioning still running | Keep returned status/URL; wait or inspect the same operation without blindly requesting another site. | Site readiness |
| Dependency/bundling failure | Inspect declarations and npm output; install missing declared packages. | Local validation |
| Manifest validation failure | Check exact field guidance and fix the error within approved edits; preserve identity/runtime. | Lint |
| Deploy rule approval | Inspect impact; reuse matching consent or resolve new consequences before retry. | Deployment |
| Already installed | Verify app/site/product/environment/version; upgrade only if needed and authorized. | Installation verification |
| Install/upgrade times out | Inspect current installation and timeout output first. Establish whether the intended version is installed or a retry is appropriate; retain matching authorization. | Installation verification or authorized retry |
| Agent absent/Rovo inactive | Verify install and activation; allow propagation. A new site needs a resolved target and scope. | Live check |
| No function logs | Check wiring and action invocation; quiet logs prove neither success nor failure. | Live action check |
| Guru returns starting links or HTTP/JSON error | Check route response and source value; fallback is not successful search. | Guru backend/live check |

For backend failures, narrate `forge logs -e development`. Avoid posting verbose payloads
or credentials. Fix narrow issues within authorization; route sustained diagnosis to
`forge-debugger` with failure, current phase, targets and attempted recovery.

When blocked, state what succeeded, what failed, and the input or external change needed.
A missing site blocks installation, not all local work. Exit stops recovery too.
Cleanup, uninstalling, deleting registrations, accepting terms and changing targets are
never implied by "retry".
