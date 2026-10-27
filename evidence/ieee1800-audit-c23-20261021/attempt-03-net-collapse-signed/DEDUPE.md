# Clause 23.3.3 net/port dedupe

Fresh live open+closed GitHub snapshot: 430 issues, 303 open, 127 closed; full snapshot is `dedupe-all-issues.json`.

Literal case-insensitive title/body searches:
- `net collapsing`, `port collapsing`, `dissimilar net`, `Table 23-1`, `wand port`, `supply port`, `uwire port`, `interconnect merge`, `signed port`, `sign extension port`: no exact phrase hits. Broad `uwire` finds closed #27, detailed below.
- `23.3.3`: #924 OPEN (array actual to array of instances), #897 OPEN (distinct user-defined nettypes at a port), #818 OPEN (unpacked struct ports), #812 OPEN (§23.3.3.2 ref port), #810 OPEN (§23.3.2.2 default empty named connection), #492 CLOSED (unpacked-array output port to array slice). #927 was filed after this 430-issue snapshot.

Lead-identified neighbors checked in the same snapshot:
- #436 CLOSED: interconnect concatenation operands; distinct from port net collapsing and interconnect merge.
- #897 OPEN: distinct user-defined nettypes with the same data type; distinct from built-in net type collapsing.
- #818 OPEN: unpacked struct ports; distinct data-type limitation.
- #924 OPEN: unpacked-array actual to array of instances; distinct connection form.
- #925 OPEN: `.name` implicit connection with non-equivalent types; distinct implicit connection check.
- #492 CLOSED: array slice on unpacked-array output port; distinct from the Table 23-1 rules.
- #27 CLOSED: broad OpenTitan UART DV bring-up umbrella; its body explicitly lists `draw_net_input.c` downgrading a `uwire` multi-driver error to a warning (treat as TRI). K7 reproduces the acceptance class, with a `vvp.tgt` warning that two-driver `uwire` is treated as a wire. The audit lead determined #27's closure did not track this conformance gap and filed #927. Add the lead-requested cross-reference comment to #27; do not reopen it.

No existing issue directly covers the selected Table 23-1 cells, interconnect merge, or sign extension through ports. The probe outputs are not yet classified by the audit lead.
