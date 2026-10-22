# Open and closed issue dedupe

Searches used `gh issue list --repo dsellerbrock/iverilog-uvm --state all`:

- `"class-scoped type cast"`: no results.
- `::T'(`: no results.
- `"8.5 cast"`: open #611; unrelated results #732 and #733.
- `class scope cast`: no results.

#611 is the exact existing scoped-cast issue. Open #766 covers specialized class-scoped type declarations and is a nearby parser/type-resolution issue, not the cast operation. Closed #666 concerns a parameterized UVM transfer `$cast` with a localparam, not a static type cast. No new issue is filed for these probes unless the non-parameterized class or package controls fail.
