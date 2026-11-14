# Compatibility options

Options that relax IEEE 1800 for code written against commercial simulators.
None of them is IEEE conformance, and none claims to reproduce any commercial
simulator's behavior. The [README](../README.md) lists the standard options.
Narrow OpenTitan queue/dynamic-array assignment and runtime interface-array
selection extensions have separately documented limits.

## `-gcommercial-unsafe`

`-gcommercial-unsafe` opts into nonstandard `bit`/`logic` element conversion for
whole assignments between queues and dynamic arrays, and for native
task/function value copies, when element width and signedness match. Same-kind
whole assignments remain strict. This option is not IEEE conformance and does
not claim to reproduce VCS behavior. It also permits a narrow mixed-driver
exception for an interface member only when every conflicting task-body write is
proven unreachable for that concrete instance. Called or uncertain tasks, active
writable port/ref aliases, and non-task writers remain errors. The flag accepts
a string-first `$fatal` as a compatibility form; strict mode still requires an
explicit finish number when arguments are present. It also lets typed mailbox
`put`/`try_put` take an assignment-compatible argument (a derived-class handle
or `null` for a class message type, or any integral/real value for an
integral/real message type, converted to that type); strict mode requires the
type equivalence of IEEE 1800 15.4.9.

`-gno-commercial-unsafe` (the default) keeps every one of these strict.
