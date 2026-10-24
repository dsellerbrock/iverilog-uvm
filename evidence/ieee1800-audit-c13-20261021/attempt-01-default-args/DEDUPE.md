# Open/closed issue dedupe for §13.5.3 probes

Source: `gh issue list --repo dsellerbrock/iverilog-uvm --state all --limit 1000`, 2026-10-21; 408 total issues, title and body searched case-insensitively.

- `default argument`: #847 OPEN (extern method argument list mismatch), #703 OPEN (ref defaults), #633 OPEN (output/inout defaults), #454 CLOSED (constructor `default` keyword).
- `13.5.3`: #703 OPEN, #633 OPEN.
- `default value`: #872 OPEN (DPI open arrays; unrelated), #810 OPEN (module-port default connection), #725 OPEN (property defaults), #708 OPEN (sequence defaults), #703 OPEN, #692 OPEN (semaphore key count), #633 OPEN, #503 CLOSED and #486 CLOSED (unrelated).
- `empty named argument`: no hits.

Focused D7 scope search on 2026-10-21: retrieved all 408 open and closed issues,
then searched title and body for `default expression scope`, `earlier formal
default`, `default argument declaration scope`, `formal default expression`,
and `subroutine declaration scope`; zero hits.

No exact title/body match covers a class-handle `= null` subroutine default or explicit empty named subroutine argument. No issue is filed by the runner; any new candidate will receive a narrower refreshed open/closed dedupe first.
