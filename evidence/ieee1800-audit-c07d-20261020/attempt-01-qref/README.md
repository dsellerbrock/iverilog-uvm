# Queue-element reference persistence probe

Probe: [`p07_10_3_ref.sv`](../../../../tests/1800_audit/c07/p07_10_3_ref.sv), run under `-g2017` and `-g2023` with a 30-second timeout for compilation and simulation. Slurm job uses the pinned Icarus 13.0-devel `cc25756d1` toolchain.

Standards text read directly from both local PDFs:

- 2017/2023 §7.10.3: “a reference to any existing element that is not deleted by the method shall not become outdated.” The same clause says queue assignment makes references to the original elements outdated.
- 2017 §13.5.2 p. 331 and 2023 §13.5.2 p. 349: “Changes made to the values of array elements by the called subroutine shall not be visible outside the scope of those subroutines if those array elements were removed from the array before the changes were made.”

Expected in both editions: R1 `1 2 99 8`; R2 `99 8`; R3 `7 2 99 8`; R4 `2 8`; R5 `2 4 8 6`.
