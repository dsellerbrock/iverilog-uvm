# OTP force RHS: copied-source compile and focused controls

The selected OTP interface calls `get_rand_mubi8_val()` on the RHS of 40
procedural `force` statements. The VVP target reports that these function RHS
values are evaluated only once. IEEE 1800-2017/2023 §10.6 requires an active
procedural continuous assignment to respond when a variable on its RHS changes.
A single saved value per target would therefore change the old force while
drawing the value for the next force.

The named `otp_ctrl_force_rhs_banked_{template,generated}.patch` overlays use
two packed enum-valued banks per partition and lock kind. The macro draws and
forces `part_access` first, then draws and forces `part_access_dai`, preserving
the original call order. A bank advances only when that partition and lock
kind are selected. The separate
`otp_ctrl_smoke_timeout_typed_endpoint_{template,generated}.patch` overlays
name the all-ones `inside` range endpoint with a `bit [TL_DW-1:0]` localparam;
the original endpoint is an independent hard compiler diagnostic.
The pinned OTP generated and template files were read only. Both generated
OTP source files in the selected FuseSoC tree byte-match the pinned files:
`otp_ctrl_if.sv` is SHA-256
`ec53a9e4fa943fd4543b3176bdacb49dcec77fa472cf5eac98e37436179ab57f`;
`otp_ctrl_smoke_vseq.sv` is
`3f7dfb3c418a55d535dd6394ee5917eab7a24dbd03f45e4ef50e7449204744e9`.
The two edited Mako templates were rendered with the pinned OTP mmap and
byte-matched their respective generated copies before the copied-source
compile. Global pinned-checkout cleanliness is not claimed during concurrent
provider work.

The separate [untyped](timeout_inside_endpoint_red.sv) endpoint reducer
fails compile with the same hard diagnostic in both strict editions. The
[typed](timeout_inside_endpoint_typed.sv) reducer compiles without warnings
and runs `PASS` in both; it checks the all-ones upper boundary and rejects
`99_999`.

`tgt-vvp/vvp_process.c` also needs a narrow correction: `force_link_rval`
asserted that a packed LHS offset was immediate, although
`force_vector_to_lval` had already evaluated the offset for
`%force/vec4/off`. The guard now applies that assertion to non-force paths.
The pre-fix packed-bank reducer aborts at `force_link_rval:2595` in strict
2017 mode. The patch leaves the function-RHS `sorry` diagnostic intact.

## Focused runtime controls

The registered `sv_force_packed_bank_rhs_live` reducer has packed struct
array targets for both DUT lanes. It verifies the active force after each new
draw, including skipped partition selection and independent read/write banks.
It also releases both packed arrays and re-forces a partition. The selected
OpenTitan task likewise releases the whole `part_access` and
`part_access_dai` arrays.

| Mode | Compile | VVP | Observation |
| --- | ---: | ---: | --- |
| strict 2017 | 0, no diagnostics | 0 | `PASS 14 draws, both lanes, skipped partition, release/re-force` |
| strict 2023 | 0, no diagnostics | 0 | same |
| strict 2017, `-DGLOBAL_BANK` | 0 | 1 | `part 0 read lane changed before re-force` |
| strict 2023, `-DGLOBAL_BANK` | 0 | 1 | same |

The negative control demonstrates why toggling all partition banks on each
selection is wrong. A separate packed-field reducer changes the selected LHS
index after force and confirms the old target remains linked. Existing
`sv_force_partial_live_overlap` and `sv_force_array_word` controls also passed
under strict 2017 and 2023 on the installed VVP target. The registered focus
harnesses passed **1/1 legacy** and **2/2 JSON**. Direct installed strict
2017/2023 compile and VVP controls passed for the combined reducer, the
dynamic-index packed-field reducer, and both adjacent force tests. The
`-DGLOBAL_BANK` runtime control failed as expected in both editions.

## Selected copied-source A/B, compile only

The [installed manifest](selected_compile.installed.result.json) records the
exact argv arrays, cwd, installed tool and source SHA-256 values, compiler
exits, diagnostic counts, source list delta, and generated VVP hashes. The
[private gate manifest](selected_compile.result.json) records the same A/B
before integration. Both selected compiles use the original OTP file list and
`-g2012 -gcommercial-unsafe -uvm` options, with the same separate
typed-endpoint source overlay. The installed VVP target SHA-256 is
`84f6a6d6fb653bb0983d4a01bca0ad99600c26e7e3eaa9d67e2fcf4a62687d84`.
Only `otp_ctrl_if.sv` differs between A and B. The current untyped endpoint
fails before VVP code generation, so the typed overlay is a prerequisite to
measuring force notices on this compiler.

| Copy | Compile exit | Force notices | Other warnings | Hard errors |
| --- | ---: | ---: | ---: | ---: |
| Original OTP interface | 0 | 40 | 56, including 36 unsafe-purity warnings | 0 |
| Banked OTP interface | 0 | 0 | Same 56 | 0 |

After removing the 40 force notices and normalizing the DPI stub output path,
the diagnostic streams match exactly. The banked image contains 80
`%force/link/off` instructions, covering both branches of each of 40 source
forces. These results qualify only compile progress on source copies; neither
selected OTP VVP image was executed.

The narrow guard and controls do not fix packed-subfield `release`: a separate
strict 2017/2023 reducer aborts at `show_stmt_release:3322`. This is recorded
in `docs/conformance/DISCOVERED_DEBT.md`; the selected OTP task releases whole
arrays and does not hit that path.
