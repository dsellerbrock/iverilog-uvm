# OTP DD-056 factory/cast diagnostic

The OTP private replay passes `cfg.randomize()` and then stops at the pinned
`dv_base_seq.sv:10` `DCLPSQ` cast for `m_edn_pull_agent[0].sequencer`. This is
not a DV pass. Its compiled image is
`/tmp/ot-otp-backdoor-path-overlay-20260924/otp-overlay.vvp` (SHA-256
`7c17498f720d6cfd721d772d57f82bb3bf08010cbdc95bd5a8553fbfa9731e54`).

The OTP bytecode has two distinct `push_pull_sequencer` class descriptors for
the same `HostDataWidth=32, DeviceDataWidth=33` values. The agent's `sequencer`
property and the sequence's `p_sequencer` property require `C0x753a056d00`
(`push_pull_agent_pkg._ivl_34` at OTP image lines 278620, 278797, 303380).
The UVM component registry used in `dv_base_agent.build_phase` is
`uvm_pkg._ivl_898` (OTP image line 279137); its `create_component` allocates
`C0x7539f32d00` (`push_pull_agent_pkg._ivl_28` at lines 43465, 1501457).
The base sequence's `$cast` tests for `C0x753a056d00` at line 303627. The two
descriptors do not have a subtype relation, explaining the runtime rejection.
Both specializations' `get_type` methods call the same registry `get` at OTP
image lines 646723 and 670889. The compiled mismatch implicates class
specialization/registry identity, independent of joint-distribution sampling.

`otp_factory_registry_reducer.sv` is a paired 2017/2023 RED. A generic agent
passes `sequencer#(32,33)` positionally into its base class. A generic consumer
spells the same type as `sequencer#(.DeviceWidth(33))`, relying on the default
host width of 32, and casts the factory-created object. The private source-tree
compiler and private VVP report `FAIL: same-parameter factory object rejected`
with exit code 1 in both language modes; an unequal-width cast is correctly
rejected. With `-DPOSITIONAL_CONTROL`, both paths spell the specialization
positionally and the same-width cast succeeds, exit code 0. The existing local
compiler also reproduces the RED in both modes. Paired logs and the reducer
are retained here; generated VVP images remain local build products. No ivtest
manifest was changed.

The compiler decision is in `elab_scope.cc`:
`canonical_specialization_parm_key_` falls back to the source-sensitive
`parmvalue_cache_key_` for this two-value-parameter class because the
multi-parameter effective-key loop requires `formal->second->type_flag`
(lines 3465-3540). `elaborate_specialized_class_type` uses the semantic cache
only for keys starting `C|`; otherwise it uses the source-key cache (lines
4013-4043). `IVL_SPEC_KEY_TRACE=sequencer` on the RED confirms positional
`O|...` and named `N|DeviceWidth=...` keys with **no semantic key**, despite
both elaborating to `HostWidth=32, DeviceWidth=33`. The trace is
`spec_key_trace_2023.log`. This is a class-specialization identity failure;
the shared UVM registry `get` in the full OTP image then masks it until the
`p_sequencer` cast. The RED isolates parameter spelling as the trigger but
does not model every UVM factory layer.

Exact private candidate commands from the worktree root:

```
for std in 2017 2023; do
  /tmp/ot-joint-private-tools-20260924/iverilog -g${std} -s otp_factory_registry_reducer -o evidence/opentitan-otp-dd056-factory-registry-20260924/otp_factory_registry_private_${std}.vvp evidence/opentitan-otp-dd056-factory-registry-20260924/otp_factory_registry_reducer.sv
  vvp/vvp evidence/opentitan-otp-dd056-factory-registry-20260924/otp_factory_registry_private_${std}.vvp
  /tmp/ot-joint-private-tools-20260924/iverilog -g${std} -DPOSITIONAL_CONTROL -s otp_factory_registry_reducer -o evidence/opentitan-otp-dd056-factory-registry-20260924/otp_factory_registry_control_${std}.vvp evidence/opentitan-otp-dd056-factory-registry-20260924/otp_factory_registry_reducer.sv
  vvp/vvp evidence/opentitan-otp-dd056-factory-registry-20260924/otp_factory_registry_control_${std}.vvp
done
```

Private compiler wrapper SHA-256:
`52adf39c42f6eee9fec58b902987cefab106b8e1785c6060b71d820712ed1e3e`;
private `ivl` SHA-256:
`302d709432e386f59a1c849d91c2fbe496b858dfde870641496888e7290db890`;
existing local `iverilog` SHA-256:
`1590b064aee694d390f8e18b1ca3469a5a47405397db9b8e385b6c5b41f1a5a2`;
private VVP SHA-256:
`bbe72e9db2dcffd0269173e21c52f6a315b9bd97f17dfda225a2c004f8ea2a8f`.

A disposable copied-source overlay can discriminate the OTP handle before UVM
starts the default device sequence. In a copy of `push_pull_agent.sv`, after
`super.run_phase(phase)` and inside the existing device/default-sequence branch,
upcast `sequencer` into `uvm_sequencer_base`, then `$cast` it back into a local
`push_pull_sequencer#(HostDataWidth, DeviceDataWidth)` and report the result.
The expected check fails if the factory created the sibling descriptor above.
Keep this overlay diagnostic separate from released DV checks; it neither fixes
the identity error nor establishes a passing OTP smoke.

Two hash-checked, disposable bytecode probes against the 88 MiB OTP image
further localize the failure. Both used the same private VVP, cwd, plusargs and
`IVL_SVA_NFA=1` as the original replay; the patch copies and logs live only in
`/tmp/otp-dd056-bytecode-probe-20260924/`.

1. `otp-cast-to-factory-descriptor.vvp` (SHA-256
   `8b15e488fcde8fa0a525843fdb76f09e0d735b615c3b215df47fed80d813c2e2`)
   changes only the `m_set_p_sequencer` `%test/class` from the required
   `C0x753a056d00` to the factory-created `C0x7539f32d00`. The DCLPSQ fatal
   disappears; execution reaches 1,559,061 ps and ends in a distinct
   `GrantKnown_A` assertion failure. Log SHA-256:
   `1baf74f51e460be376d1d6dfbd5dc7c345c8c9779e43ce5ff507eaf2b5c1475f`.
2. `otp-factory-to-required-descriptor.vvp` (SHA-256
   `6e1a1ecea792549b2d38ba596ea932fb7cb7bb5c63c620cb034bb77f57b557ef`)
   changes the factory allocation, constructor call and registry-return cast to
   the required descriptor. DCLPSQ disappears but the run fails at 0 ps on
   null sequencer TLM ports and `BUILDERR`. This shows bytecode substitution
   is not a repair. Log SHA-256:
   `3ad669acb234e1ab9b0ace0b4656b7647419f84e6343edb72d3b90aaa7483afa`.
