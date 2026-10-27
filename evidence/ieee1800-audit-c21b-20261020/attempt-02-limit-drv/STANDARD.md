# IEEE 1800 extended VCD follow-up

The relevant subsection numbers match in IEEE 1800-2017 and 1800-2023.

- §21.7.3.4 (2017 p. 665; 2023 p. 695): `$dumpportslimit(filesize, filename)` takes a byte limit. When reached, dumping stops and a comment is inserted saying the limit was attained.
- §21.7.3.7 (2017 pp. 665–666; 2023 p. 696): a control task whose filename matches no `$dumpports` file is ignored.
- §21.7.4.3.2 (2017 p. 671; 2023 p. 701): for conflicts, equal-value input and output drivers in the same strength range produce state `0`/`1`; a strong input against a weak output produces `d`/`u`; a weak input against a strong output produces `l`/`h`. Strength ranges 7–5 are strong and 4–1 are weak.

Before running, the driver probe is expected to encode: input-only low `D`; strong input plus weak output, both low, `d`; weak input plus strong output, both low, `l`; equal strong low drivers `0`; equal weak low drivers `0`; then no active drivers `F`. The file-size probe uses a 200-byte limit on one file and leaves a second file unlimited. The unmatched `$dumpportsoff("unmatched.evcd")` call must not stop either matching file; the unlimited file must continue recording changes. The limited file should stop near its limit, within one final record, and include the required limit comment.

The probes use continuous assignments for every testbench and DUT driver, matching §21.7.4.3.2's driver model. The same source is compiled and run under `-g2017` and `-g2023`.
