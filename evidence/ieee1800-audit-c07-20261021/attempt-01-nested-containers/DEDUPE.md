# Open and closed issue dedupe: nested containers and class-element methods

Fetched all issues from `dsellerbrock/iverilog-uvm` before the probes with `gh issue list --state all --limit 1000`; [`dedupe-all-issues.json`](dedupe-all-issues.json) contains 424 issues: 297 open and 127 closed. Searched titles and bodies in both states for nested associative/queue containers, queue copy/assignment, `foreach` over queues, class-element locators/sort/reduction, dynamic arrays of queues, multi-index method receivers, and stacked container lvalues.

No exact duplicate covers the selected interactions. Relevant nearby issues are distinct:

- #427 (open) concerns task `ref` aliases to container elements and alias lifetime across nested/class-property paths; these probes use direct value reads/writes and built-in methods, with no `ref` alias.
- #424 (open) concerns locator result types consumed through wrapper/call expressions; A6 assigns direct locator results to typed queues without a wrapper.
- #484 (open) covers associative arrays whose elements are fixed unpacked arrays; A1 uses queues as associative elements and A5 uses a dynamic array of queues.
- #490 (closed) covers ordering methods on fixed-array class properties; A7 sorts a queue of class handles using an element-property expression.
- #851 (open) covers `sum` on a multidimensional unpacked array; A8 sums a queue of class handles using `int'(item.v)`.
- #854 (open) covers the optional iterator-name argument added in 2023; A6 uses the ordinary locator form.
- #97 (closed) covers a compiler crash writing a class property through a fixed unpacked-array element; A4 uses an associative-array class handle and calls its method.
- #486 (closed) concerns reading a nonexistent associative entry, while A10 pushes into a missing key's queue and checks entry creation.
- #849/#850 (open) cover queue `$` lvalue syntax and empty queue pops, not these nested operations; #11/#15 are broad older project milestones.

Other broad search hits (#903, #858, #856, #853, #852, #850, #849, #803, #485, #494 and #478) concern file I/O, unrelated array ranks, associative-key crashes, array method arguments, queue empty behavior, constraint functions, transactional assignment, or constraint identity. None duplicates A1–A10.
