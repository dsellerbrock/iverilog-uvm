# §7.12.4/.5 open-and-closed issue dedupe

Repository `dsellerbrock/iverilog-uvm`; searches run 2026-10-20.

| Search | Open matches | Closed matches | Review |
|---|---|---|---|
| `map()` | none | none | — |
| `array map` | #485 | #505, #487, #27 | #485 concerns variable-sized associative pattern assignment; #505 shortreal array arguments; #487 foreach packed-rank traversal; #27 OpenTitan UART runtime stubs. None concerns array mapping. |
| `7.12.5` | none | none | — |
| `7.12.4` | none | none | — |
| `iter_index` | none | none | — |
| `array iterator` | none | none | — |
| `iterator index` | none | none | — |
| `iterator argument` | none | none | — |
| `find(item` | none | none | — |
| `index argument` | #853, #803, #671 | #157, #27 | #853 is a struct associative-array-key runtime crash; #803 is readmemh/writememh array-argument support; #671 is dynamic-array slice assignment in class properties; #157 is a UVM regex DPI null-input issue; #27 is an OpenTitan UART harness issue. None concerns the optional iterator index argument. |
| `array method index` | #851, #850, #429 | #27 | #851 is multidimensional reduction; #850 is empty queue pop defaults; #429 covers indexed class-array member reads/writes/method receivers; #27 is unrelated. None covers iterator index renaming or `map()`. |

Reviewed each matching issue body. No duplicate covers the §7.12.4 iterator-index argument or §7.12.5 mapping behavior.
