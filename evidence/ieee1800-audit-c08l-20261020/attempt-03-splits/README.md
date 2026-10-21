# §8.23 / §8.26 specialized type-scope reducers

The combined S1–S5 source in attempt 02 failed in several contexts. This
attempt gives each standards-defined form its own compilation unit to identify
which class-scope type selections fail. Each is compiled and run in both
editions with a 30-second process-group timeout.

The cases are: S1 specialized ordinary-class typedef in a variable; S2
specialized interface-class typedef in a variable; S3 typedef inherited via
interface-class `extends`; S4 specialized ordinary-class typedef in a function
return type; S5 inherited interface-class typedef in a function return type.
The audit lead identified existing issue #766 as overlapping S1–S3; the full
issue dedupe remains in attempt 02.
