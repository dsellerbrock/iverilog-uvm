# Open and closed issue dedupe for #801 and #802

Queried `dsellerbrock/iverilog-uvm` with `gh issue list --state open` and
`--state closed` on 2026-10-20. Raw JSON is saved in the adjacent
`dedupe-*.json` files.

## #801 — `%p` of an associative array of structs

- `"associative array of structs"` and `"prints question marks"` each return
  only #801 in open issues; closed results are empty.
- The broader `"%p struct"` search also returns #802 because the issue text
  shares formatting vocabulary; #802 is about enum formatting. The
  `"%p assignment pattern"` search returns no result.
- No other open or closed issue describes `%p` losing struct values inside an
  associative array.

## #802 — `%p` prints an enum numerically

- `"%p enum"` and `"enumerated value as a number"` each return only #802 in
  open issues; closed results are empty.
- `"enum name"` also returns open #738 (enum methods on an array element) and
  #791 (`$typename` spelling), and closed #11/#47 (enum method work). These
  concern different APIs and do not cover `%p` formatting.
- No other open or closed issue describes `%p` printing an enum's numeric
  value instead of its enumerator name.
