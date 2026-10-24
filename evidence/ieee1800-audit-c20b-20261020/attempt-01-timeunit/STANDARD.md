# IEEE 1800-2023 §20.4.1 time-unit retrieval

Section 20.4.1 says the `$timeunit` and `$timeprecision` system functions return the unit and precision for the current design element, or the element named by their optional hierarchical identifier. It specifies: “The return value shall be an integer in the range from 2 to -15.” Table 20-2 encodes the powers of ten: 1 ns = -9, 1 ps = -12, 100 us = -4, and 10 ns = -8.

Thus `p20_04_1_tu` expects `TU -9 -12 -4 -8` under `-g2023`. In the local IEEE 1800-2017 text, these system functions do not appear; rejection under `-g2017` is the edition control.

Text source: local IEEE 1800-2023 PDF §20.4.1, printed p. 622, extracted lines 40885–40932. Edition-control check: local IEEE 1800-2017 PDF text, no `$timeunit` or `$timeprecision` occurrence.
