# Clause 4 issue dedupe

Searches used `gh issue list --repo dsellerbrock/iverilog-uvm --state all`, covering both open and closed issues, for: `"scheduling region"`, `"inactive region"`, `"NBA order"`, `"$strobe postponed"`, `"4.4"`, `"4.7"`, `"consecutive NBAs"`, `"last one wins" "nonblocking"`, `"same variable" "nonblocking assignment"`, and `"multiple nonblocking assignments" SystemVerilog`.

No hits appeared for the behavior-specific searches. The broad clause-number searches returned issues in unrelated clauses (for example #653 §9.4.4, #857 §10.9.2, #896 §16.13.5/§16.13.6, and #880 §32.7); none duplicates this region-order, program Reactive, or same-process NBA-order probe. The paired-edition run passed, so no new issue is proposed.
