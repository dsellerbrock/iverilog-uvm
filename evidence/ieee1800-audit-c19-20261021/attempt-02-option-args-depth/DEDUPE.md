# Open/closed issue dedupe for §19.7 option probe

Source: GitHub issue list queried with `gh issue list --state all --limit 1000`; results filtered case-insensitively across title and body on 2026-10-21.

- `covergroup option`: #835 (open), #687 (open), #510 (closed), #19 (closed).
- `option.at_least`: #835 (open), #689 (open).
- `option.weight`: #835 (open), #689 (open), #686 (open), #19 (closed).
- `option.goal`: #689 (open), #19 (closed).
- `not a constant; using default`: #835 (open).
- `19.7`: #835 (open), #689 (open), #687 (open), #686 (open).
- `option inheritance`: no matches.
- `coverpoint option override`: no matches.

Issue routes: #835 is the existing nonconstant definition-time option fallback; #689 covers procedural goal/comment options. No current issue covers a constant `at_least` parameter or a constant Table 19-2 default/override failure. No issue is filed by this runner; the lead files new issues after reviewing the exact probe outcomes.
