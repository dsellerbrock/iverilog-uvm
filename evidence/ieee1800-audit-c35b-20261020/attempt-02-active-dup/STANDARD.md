# IEEE 1800 clauses used by the DPI task probe

References checked in both IEEE 1800-2017 and IEEE 1800-2023.

## §35.4 — Global name space of imported and exported functions

The linkage names for imported and exported tasks/functions share a global
namespace and must be unique; overloading is not allowed. Multiple declarations
of the same global subroutine can appear in different scopes.

## §35.5.4 — Import declarations

For any given `c_identifier`, all declarations in any scope must have the same
type signature, including the return type, every argument's number, order,
direction and type, plus the `pure`/`context` qualifiers and DPI version string.
Short exact excerpt: “all declarations ... shall have exactly the same type
signature.”

The positive source maps C linkage name `c_add2` to the local SV name
`my_add`. The negative source repeats `c_add2` with a different signature and
must be rejected under §§35.4 and 35.5.4.

## §35.8 — Exported tasks

An imported task may call an exported task only when the import is declared
`context`. `c_task_call` exercises this path and checks that simulation time
advances through the exported task before the import returns.

## §35.9 — Disabling DPI tasks and functions

Short exact excerpt: “When an exported task returns due to a disable, it shall
return a value of 1.” An imported task returning due to disable must likewise
return 1. An imported function instead checks `svIsDisabledState()` and calls
`svAckDisabledState()` before returning. These are distinct protocol paths:
the probe verifies both and ensures the disabled SV processes do not continue.
It does not call `svAckDisabledState()` from the imported task.
