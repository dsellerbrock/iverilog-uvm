# Recover a blocked main merge

The `main` ruleset requires a pull request and the `Fast Linux` check. Its bypass list is intentionally empty. If GitHub Actions is unavailable and an urgent repair cannot pass that check, the repository owner can temporarily turn off enforcement for the existing ruleset, merge the repair, and immediately turn enforcement back on.

This disables all rules in the ruleset, including force-push and deletion protection. Use it only for the short recovery window. The commands require `gh`, `jq`, and repository administration access. They preserve the existing rules and empty bypass list; only `enforcement` changes.

```sh
repo=dsellerbrock/iverilog-uvm
ruleset=15514526
endpoint="repos/$repo/rulesets/$ruleset"
current=$(mktemp)
payload=$(mktemp)
trap 'rm -f "$current" "$payload"' EXIT

gh api "$endpoint" > "$current"
jq '.enforcement = "disabled" | {name, target, enforcement, bypass_actors, conditions, rules}' \
  "$current" > "$payload"
gh api --method PUT "$endpoint" --input "$payload"
```

Merge only the urgent repair while enforcement is disabled. Then restore protection immediately:

```sh
gh api "$endpoint" > "$current"
jq '.enforcement = "active" | {name, target, enforcement, bypass_actors, conditions, rules}' \
  "$current" > "$payload"
gh api --method PUT "$endpoint" --input "$payload"
gh api "$endpoint" --jq '{name, enforcement, bypass_actors, rules}'
```

Confirm the result reports `enforcement: active`, an empty `bypass_actors` array, deletion and non-fast-forward protection, pull-request requirements, and the required `Fast Linux` status check. If a temporary update fails, do not merge; restore or verify the active ruleset first.
