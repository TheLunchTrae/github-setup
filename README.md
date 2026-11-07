# github-setup

My common setup for new GitHub repos: branch rulesets, Actions policies, merge and security settings.

```bash
./apply.sh OWNER/REPO --check "CI / test" --dry-run   # preview
./apply.sh OWNER/REPO --check "CI / test"             # apply
./apply.sh OWNER/REPO --check "CI / test" --npm       # npm package repo
```

Needs the GitHub CLI signed in with admin rights on the target repo, and the default branch must already exist (push an initial commit first, since `Main: Block Creation and Deletion` has no bypass). Re-running updates rulesets in place by name.

## Rulesets

All target the default branch. Rules are split so each can be bypassed on its own; creation and deletion share one ruleset.

| Ruleset | Rule | Bypass |
| --- | --- | --- |
| Main: Block Creation and Deletion | Block creating or deleting the default branch | None |
| Main: Block Force Pushes | Block force pushes | None |
| Main: Require PR | Require a PR, squash merge only | None |
| Main: Require Approval | Require 1 approving review | Repository admins, exempt |
| Main: Require Code Owner Review | Require a CODEOWNERS review | Repository admins, exempt |
| Main: Require Status Checks | Require the `--check` contexts to pass | Repository admins, exempt |

Exempt means the rules are skipped entirely for that actor, not offered as a manual bypass. On a personal repo the only admin is the owner; on an org repo it covers every repo admin, including org owners. The status checks ruleset is only applied when at least one `--check` is passed. The code owner rule needs a `CODEOWNERS` file in the target repo.

### npm package tags

Opt-in with `--npm`, from `rulesets/npm/`. Only admins can create release tags, and no tag can be moved or deleted. Tags created by Actions with `GITHUB_TOKEN` (release-please, changesets, semantic-release) are blocked unless that app or a deploy key is added to the `Version Tags: Block Creation` bypass.

| Ruleset | Rule | Bypass |
| --- | --- | --- |
| Other Tags: Block Creation | Block creating tags other than `v*` | None |
| Version Tags: Block Creation | Block creating `v*` tags | Repository admins, exempt |
| Tags: Block Updates and Deletion | Block moving or deleting any tag | None |

Rulesets on private repos need GitHub Pro (personal) or Team (org); the script skips them otherwise and applies everything else.

## Settings

- `settings/repo.json`: squash merge only (PR title and body), auto-delete head branches, update-branch button, auto-merge off, web commit sign-off, Projects off.
- `settings/actions-permissions.json`: Actions on, all actions allowed.
- `settings/actions-workflow-permissions.json`: read-only `GITHUB_TOKEN`, workflows can't approve PRs.
- Dependabot alerts and security updates on. Public repos also get secret scanning, push protection and private vulnerability reporting.
