# Open and closed issue dedupe

All searches used `gh issue list --repo dsellerbrock/iverilog-uvm --state all`:

- `"readmemh dynamic array queue"`: no results.
- `"readmem queue"`: no results.
- `"21.4.1 dynamic array queue"`: no results.
- `"readmemb queue"`: no results.

Existing open #803 is explicitly limited to associative-array arguments, with integral index requirements and the corresponding read/write reproducer. It does not cover dynamic arrays or queues. No matching closed issue appeared in the searches.
