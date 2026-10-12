# Proposal: protect `main`

## Evidence

The GitHub branch-protection API currently reports that `main` has no protection rules. CI runs the full six-lane matrix, and recent history includes both functional failures and runner shutdowns.

## Proposal

Add a repository ruleset for `main` that blocks force pushes and deletion, requires pull requests, and requires the Linux CI check before merge. Keep the full platform matrix visible and use it as the manual merge gate until the fast smoke tier is measured and adopted.

Start with a simple required-check rule. Consider a merge queue only if concurrent merges continue to create avoidable CI churn; the October 9–10 canceled runs alone do not establish that a queue would solve the cause.

## Tradeoff

A required check protects against unvalidated changes but can block merges during GitHub runner outages. Define a documented maintainer recovery path before enabling the rule.

## Status

Proposal only. Repository settings are not changed by this document.
