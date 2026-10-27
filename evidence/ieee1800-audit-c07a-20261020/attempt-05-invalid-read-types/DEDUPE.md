# Open and closed issue search — invalid queue reads

GitHub issue searches used `--state all` so both open and closed issues were
included:

| Search | Matches | Review |
|---|---|---|
| `queue "invalid read"` | none | No direct match |
| `queue "invalid index"` | #849, #850 (open) | #849 is `$+1` write parsing; #850 is empty `pop_front()`/`pop_back()` on 2-state queues |
| `queue "out of range" read` | #27 (closed) | OpenTitan UART runtime umbrella; its body/comments do not cover queue-read default values |
| `queue "nonexistent" entry` | #850 (open) | Discusses empty pop values and records the correct zero read from a 2-state `int` queue; no 4-state `logic` queue-read gap |
| `7.10.1 queue` | #849 (open) | Same `$+1` l-value parser gap |
| `logic queue` | #850 (open), #788/#792 (open), #27 (closed) | #850 concerns empty pops on 2-state queues; #788/#792 concern `$bits` and array-query results; #27 is unrelated OpenTitan work |
| `queue "read operation"` | none | No direct match |
| `queue "Table 7-1"` | #850 (open) | Empty-pop defaults, not the 4-state invalid queue-read behavior |

No issue will be proposed unless the corrected paired-edition probe reveals a
standard mismatch. The earlier job 3561 had a test-design error: §6.11 says
`int` is 2-state, so Table 7-1 requires zero.
