# Proposal: make open PR sync on demand

## Current behavior

`.github/workflows/sync-pr-branches.yml` runs when `main` is pushed, every hour, and by manual dispatch. The hourly run can update every open PR branch whether or not its owner needs a sync at that time.

## Proposal

Remove the hourly schedule while retaining the `main` push trigger and manual dispatch. The push trigger keeps open branches current after main changes; manual dispatch remains available to sync all branches or one selected PR when needed.

## Tradeoff

Without the hourly run, a PR can remain behind `main` between main pushes. That is acceptable if CI revalidates the PR head and maintainers can request a manual sync; it avoids periodic write operations against every open PR.

## Status

Proposal only. The workflow is unchanged by this document.
