# IEEE 1800 assertion-control requirements

- IEEE 1800-2017 §20.12, printed pp. 608–610; IEEE 1800-2023 §20.11, printed pp. 637–639: `$assertcontrol` controls assertion evaluation and assertion action blocks. The optional assertion-type mask defaults to 255; the optional directive-type mask defaults to 7; omitted hierarchy levels defaults to 0. Table 20-5 defines control values 3=On, 4=Off, 5=Kill, 8=FailOn, and 9=FailOff.
- Both editions define `$asserton`, `$assertoff`, and `$assertkill` using the corresponding `$assertcontrol` operation and allow an optional hierarchy level and list of scopes or individual assertions.
- IEEE 1800-2017 and 1800-2023 §16.3 say simple-immediate assertion pass/fail action execution is controlled by assertion action control tasks. The §20.12/§20.11 description explicitly identifies assertion types; assertion-type value 3 is `Concurrent|SimpleImmediate`.

Source: the local licensed 1800-2017 and 1800-2023 PDFs. Clause references are recorded so the tested behavior can be checked directly against those editions.
