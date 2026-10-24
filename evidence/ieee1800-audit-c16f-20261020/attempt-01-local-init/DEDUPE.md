# §16.13.7 issue dedupe

Searched both open and closed issues in `dsellerbrock/iverilog-uvm` for:

- `16.13.7`
- `"local variable initialization"`
- `"semantic leading clock"`
- `property local variable initializer`

No matching open or closed issue was returned. The raw search results are in
[`dedupe/`](dedupe/). The probe verifies a parse rejection at the standard's
`logic v = e;` declaration, and the existing §16.10 local-variable control
passes. The candidate is unique based on these searches; lead classification
and any issue filing remain pending.
