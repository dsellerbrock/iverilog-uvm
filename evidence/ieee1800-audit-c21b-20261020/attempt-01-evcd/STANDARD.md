# IEEE 1800 extended VCD behavior

The relevant clause numbering is the same in both editions.

- IEEE 1800-2017 §21.7.3.1 (pp. 663–664) and IEEE 1800-2023 §21.7.3.1 (pp. 693–694) specify `$dumpports(scope_list, filename)`. Its calls must occur at the same simulation time, and scopes and filenames must be unique. This repeated-call rule is in §21.7.3.1, not §21.7.3.7.
- §21.7.3.2 specifies `$dumpportsoff(filename)` and `$dumpportson(filename)`; §21.7.3.4 specifies `$dumpportslimit(filesize, filename)`; §21.7.3.5 specifies `$dumpportsflush(filename)`.
- IEEE 1800-2017 §21.7.3.4 (p. 665) and IEEE 1800-2023 §21.7.3.4 (p. 695) require that when the file-size limit is reached, dumping stops and “a comment is inserted into filename indicating the size limit was attained.”
- §21.7.3.7 (2017 pp. 665–666; 2023 p. 696) says a control task with a filename that does not match a `$dumpports` filename is ignored. Tasks with only optional arguments may be called without parentheses or with empty parentheses to invoke their default actions. This probe uses explicit matching filenames, so those §21.7.3.7 rules are not exercised.
- IEEE 1800-2017 §21.7.4.1–§21.7.4.3 (pp. 666–670) and IEEE 1800-2023 §21.7.4.1–§21.7.4.3 (pp. 696–700) define the header, node declarations and value-change record grammar. The header contains date, simulator version and timescale, then port scopes/declarations; records use `p` immediately followed by the port state, the 0/1 strength digits, and the `<integer` identifier.
- §21.7.4.3.2 (2017 p. 671; 2023 p. 701) specifies driver resolution and conflict states. §21.7.4.4 (2017 pp. 671–672; 2023 pp. 701–702) gives a larger example. The assigned inverter in this minimal probe does not exercise multiple-driver resolution or reproduce the full example.

The standard task prototypes exercised are `$dumpports(u,"p21.evcd")`, `$dumpportslimit(400,"p21.evcd")`, `$dumpportsoff("p21.evcd")`, `$dumpportson("p21.evcd")`, and `$dumpportsflush("p21.evcd")`.
