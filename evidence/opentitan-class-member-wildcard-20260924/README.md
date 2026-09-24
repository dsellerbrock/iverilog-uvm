# OpenTitan class member and wildcard import — 2026-09-24

Pinned source: Earlgrey-PROD-M6 `a78922f14a8cc20c7ee569f322a04626f2ac6127`, clean before and after isolated replay. Installed Icarus `ivl` SHA-256: `6ec92c4825dc51e3810d1cb22405071f033015626d39cf3db92c319aeb9d3b10`. No pinned source or shared installation was changed.

Both scrambler packages export `string path`; `mem_bkdr_util_pkg.sv` wildcard-imports both before including `mem_bkdr_util.sv`. Its class declares `protected string path`, yet the unqualified reference in `convert2string()` at line 130 is reported ambiguous. The isolated pinned OTP and chip UVM compile rows each set up with exit 0 and fail compilation with exit 1 and only this hard error. No runtime was attempted. Setup retains FuseSoC mapping and ignored C/C++ DPI-source warnings. [`result.json`](result.json) records bounded diagnostics and source/reducer hashes; full local work trees remain in `/tmp/ot-path-lookup-7hFJ9H/`.

The paired reducer `member.sv` is RED in `-g2017` and `-g2023` with the same diagnostic. `ambiguous.sv` deliberately has no class member and must reject. `explicit.sv` uses `this.path`, and `single_import.sv` has one wildcard import; each compiles and prints `PASS member` in both editions. Focused commands from the campaign checkout:

```sh
for edition in 2017 2023; do
  for case_name in member ambiguous explicit single_import; do
    local-install/bin/iverilog -g"$edition" \
      -o "/tmp/ot-path-lookup-7hFJ9H/$case_name-$edition.vvp" \
      "evidence/opentitan-class-member-wildcard-20260924/$case_name.sv"
    if test -f "/tmp/ot-path-lookup-7hFJ9H/$case_name-$edition.vvp"; then
      local-install/bin/vvp "/tmp/ot-path-lookup-7hFJ9H/$case_name-$edition.vvp"
    fi
  done
done
```

Pinned OTP replay, with all generated outputs isolated under `/tmp`:

```sh
/opt/homebrew/opt/python@3.13/bin/python3.13 scripts/opentitan_matrix.py \
  --opentitan-root /Users/danielellerbrock/projects/iverilog_uvm/clean-corpora/opentitan-7a3ad34 \
  --build-root /tmp/ot-path-lookup-7hFJ9H/otp-replay/work \
  --result-json /tmp/ot-path-lookup-7hFJ9H/otp-replay/results.json \
  --result-md /tmp/ot-path-lookup-7hFJ9H/otp-replay/results.md \
  --iverilog local-install/bin/iverilog \
  --uvm-home third_party/uvm-releases/sources/1.2/uvm-1.2/src \
  --fusesoc /Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin/fusesoc \
  --fusesoc-python /Users/danielellerbrock/projects/iverilog_uvm/evidence/arm64-tooling/opentitan-python313/bin/python \
  --lane uvm --core lowrisc:dv:otp_ctrl_sim:0.1 \
  --setup-timeout 120 --compile-timeout 120
```

The chip replay uses the same command with `otp-replay` replaced by `chip-replay` and core `lowrisc:dv:chip_sim:0.1`. Hashes of `mem_bkdr_util_pkg.sv`, `mem_bkdr_util.sv`, `otp_scrambler_pkg.sv`, and `sram_scrambler_pkg.sv` match byte for byte between the pinned checkout and OTP generated snapshot; the chip copy of `mem_bkdr_util.sv` also matches.

## Inherited-property boundary

Inherited lookup is a separate RED. [Bounded follow-on evidence](lookup_follow_on_red.json)
shows that `inherited.sv` and `scoped_base.sv` falsely reject a protected
base property in both editions on the installed and final direct-only
candidate compilers. The local-property negatives correctly reject. A
previous private attempt re-resolved `extends P::B` as an unrelated nearer
`B`, so it was removed instead of suppressing a real package ambiguity.
Parameterized base types also need deferred resolution. These cases are
preserved as focused source fixtures here, not registered as passing tests.
A property declared later in the same class also remains false-ambiguous
when two packages export its name; `late_direct_property_control.sv` proves
the forward class reference runs when those imports are absent.

## Private compiler and released replay

`pform.cc` checks an already-declared property in the active class before
turning an enclosing wildcard import into an explicit package reference.
The coordinator built `ivl` with `make -j1 ivl` and copied
it to an isolated `-B` tool root; the installed compiler used by active
Caliptra runs remains SHA-256 `6ec92c4825dc51e3810d1cb22405071f033015626d39cf3db92c319aeb9d3b10`.
The final private `ivl` SHA-256 is
`37f1af94081d8a3042ad4f8bb11e61705c24a74c73f3748e9c82dbe59c9287b8`.

[Final paired focus](direct_focus_final.json) has 44 compiler invocations
across 2017 and 2023: the installed compiler rejects the legal direct
class property, while the candidate compiles and runs it in both editions
with `PASSED`. A no-member ambiguity and an invalid call of a shadowing data
property reject with identical diagnostics on both compilers. Eight neighboring
wildcard-import cases retain their compile exit and diagnostics in each edition. The registered
[JSON](../../ivtest/regress-opentitan-class-member-wildcard-focus-vvp.list)
and [legacy](../../ivtest/regress-opentitan-class-member-wildcard-focus-legacy.list)
focus harnesses each pass 6/6 on the candidate, including exact negative
diagnostic gold files. Their outputs are `direct-focus-vvp.log` and
`direct-focus-legacy.log` here. Adjacent class-shadow, package-qualified,
and pform-release focus suites pass 90/90 combined across JSON and legacy;
their six `direct-adjacent-*.log` outputs are here.

[Final pinned OTP/chip replay](release_replay_final.json) uses the same
private compiler and clean Earlgrey-PROD-M6 source. Both FuseSoC setups
return 0, and neither compile reports the old class-member ambiguity. OTP
then fails compile with 26 other hard errors (exit 28); chip fails with 64
other hard errors and an abort (exit 134). Both hit four indexed
dynamic-array slice errors in `sram_scrambler_pkg.sv`. Neither starts runtime
or establishes a clean OpenTitan DV pass. The full local runner results are
under `/tmp/ot-class-member-replay-20260924/`.
