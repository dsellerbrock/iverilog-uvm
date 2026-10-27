# IEEE 1800 display, flush, and I/O error behavior

The edition numbering for these clauses is unchanged.

- IEEE 1800-2017 §21.2.1 and §21.2.1.2–§21.2.1.3 (pp. 624–629); IEEE 1800-2023 §21.2.1 and §21.2.1.1–§21.2.1.2 (pp. 654–659): unformatted arguments use decimal for `$display`/`$write`, binary for `*b`, octal for `*o`, and hexadecimal for `*h`. For decimal values, leading zeroes are replaced with spaces; an 8-bit unsigned value needs three columns to display its largest value, 255. An empty argument produces one space, while `$display` without arguments emits a newline.
- IEEE 1800-2017 §21.3.6 (pp. 644–645) and IEEE 1800-2023 §21.3.6 (p. 674): `$fflush` accepts an MCD, file descriptor, or no argument; the no-argument form flushes all open files.
- IEEE 1800-2017 §21.3.7 (p. 645) and IEEE 1800-2023 §21.3.7 (pp. 674–675): `$ferror(fd,str)` returns the error code for the most recent file I/O operation and stores a description in `str`; after a non-error, it returns zero and clears `str`.

Relevant standard wording: §21.2.1.2 (2017) / §21.2.1.1 (2023) uses “default decimal format” for unformatted `$display` and `$write` arguments; §21.2.1.3 (2017) / §21.2.1.2 (2023) says “leading zeros are suppressed and replaced by spaces.” §21.2.1 in both editions states: “An empty argument produces a single space character in the display.” §21.3.6 gives `$fflush(mcd)`, `$fflush(fd)`, and `$fflush()` forms. §21.3.7 says: “If the most recent operation did not result in an error, then the value returned shall be zero, and the str variable shall be cleared.”

The probe checks default radices and automatic widths, adjacent-comma and no-argument output, `$fflush(fd)` visibility to a separately opened reader, `$ferror` after successful `fgets`, and the simulator's observable result after a failed `$fopen`. The last case is recorded as an observation: the standard does not explicitly define `$ferror` when the failed open leaves `fd` equal to zero.
