# Local IEEE 1800 references

Keep personal reference copies of the SystemVerilog standards in the ignored
`docs/standards/local/` directory using these stable names:

- `IEEE_Std_1800-2017.pdf`
- `IEEE_Std_1800-2023.pdf`
- `IEEE_Std_1800-2017_errata.pdf`

IEEE 1800-2017 and IEEE 1800-2023 are both first-class selectable conformance
targets in this project (`-g2017` and `-g2023`). The 2023 edition supersedes
2017 as a publication, but it does not erase the behavior users explicitly
select in 2017 mode. Audits must consult the selected edition and applicable
errata, and paired tests must record whether a rule is shared or intentionally
different.

Obtain personal copies through the official IEEE GET program:

- IEEE 1800-2023: <https://standards.ieee.org/ieee/1800/7743/>
- IEEE GET program: <https://ieeexplore.ieee.org/browse/standards/get-program/page>
- IEEE 1800-2017 record: <https://ieeexplore.ieee.org/document/8299595>
- IEEE 1800-2023 record: <https://ieeexplore.ieee.org/document/10458102>
- IEEE 1800-2017 errata: <https://standards.ieee.org/wp-content/uploads/import/documents/erratas/1800-2017_errata.pdf>

The PDFs remain copyrighted IEEE material and must not be committed or
redistributed; `docs/standards/local/` is ignored. Record the source URL and
SHA-256 digest in a local manifest next to the PDFs. A local reference helps
implementation work, but compatibility claims still require executable
positive, negative, interaction, and differential tests. VCS, Questa, and
Xcelium are the practical commercial interoperability cross-checks after the
IEEE text; Slang is a parser/elaboration differential, and Verilator is
diagnostic evidence rather than this project's language or ABI oracle.
