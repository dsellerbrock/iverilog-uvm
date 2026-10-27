# Assertion action-block region requirement

IEEE 1800-2017 §4.4.2.5 says assertion pass/fail code is scheduled in the Reactive region. Section §4.4.2.6 states that “code in action blocks of concurrent assertions are scheduled in the Reactive region” (PDF p.63).

IEEE 1800-2023 §4.4.2.5 has the same requirement. Section §4.4.2.6 states that “code in action blocks of concurrent assertions are scheduled in the Reactive region” (PDF p.66).

Thus S4 expects the failed assertion's action block to observe `x=1` after the NBA update. The section number is §4.4.2.6 in both PDFs; §4.4.2.7 is Re-Inactive.
