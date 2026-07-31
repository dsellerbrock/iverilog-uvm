# Findings ledger — recovery campaign, 2026-07-31

Every entry here was reproduced by the lead against a build of this tree, not
taken on report. Where a finding came from a subagent and was NOT independently
reproduced, it says so.

Diagnostics are counted with:

    iverilog -g2012 -s<ip> [-DSYNTHESIS] -c <ip>.scr -o /dev/null

`-DSYNTHESIS` selects `prim_assert_dummy_macros.svh`, i.e. assertions OFF. The
fusesoc builds need `--mapping lowrisc:prim_generic:all:0.1`.

Counting `: error:` lines alone is not a status check — a compiler ABORT prints
no such line. Always take the exit status too. That mistake is what recorded
otbn as "0 errors" while it was aborting; see FIXED-2.

---

## 1. State by mode

### Synthesis (`-DSYNTHESIS`), measured at `fbd32f4c`

    ip           exit   diagnostics
    hmac           0        0
    otbn           0        0        (was exit 134, a compiler abort)
    spi_device     0        0        (was 1)
    aes            3        3        2 distinct roots
    kmac           7        7        2 distinct roots

### SVA (assertions enabled), 186 diagnostics over five IPs

    spi_device 36 | aes 39 | hmac 32 | otbn 47 | kmac 32

By ROOT, which is what matters — the per-IP counts are mostly repetition:

    70  `or'/`and' combinator as an implication ANTECEDENT
    45  cycle delays must be literal constants   (##[0:SkewCycles] — a PARAMETER)
    17  antecedent shape unsupported             (same representation gap as the 70)
    17  syntax error
    12  parenthesized property as CONSEQUENT
     8  $past depth must be literal              (same root as the 45)
     5  repetition shape
     5  Invalid module item                      (cascade)
     2  sequence spans > 512 cycles
     2  Malformed statement                      (cascade)
     2  Error in property_spec                   (cascade)
     1  parameterized property with a leading clock

Two changes account for 135 of 186:
  * a recursive property representation — `sva_property_t::antecedent` is a flat
    step chain and a combinator is a tree (the 70 + 17, and part of the 12);
  * moving SVA bound evaluation out of pform, where parameters do not exist yet,
    into elaboration (the 45 + 8).

### UVM

Two different things, and they must not be conflated:

    fork's own UVM regression (.github/uvm_test.sh)   229/229, green on every commit
    OpenTitan UVM DV common layer                     compiles clean, 0 errors
    OpenTitan per-IP DV environments                  NOT YET ATTEMPTED

The OpenTitan DV common layer verified clean: `uvm_pkg`, `dv_utils_pkg`,
`str_utils_pkg`, `bus_params_pkg`, `top_pkg`, `dv_base_reg_pkg`,
`csr_utils_pkg`, `dv_base_agent_pkg`, `dv_lib_pkg`. Compile with `-DUVM`;
without it `dv_macros.svh` defines `` `gfn `` as `$sformatf("%m")` and
`x.`gfn` is then a genuine syntax error in the SOURCE, not a compiler defect.

---

## 2. Fixed this campaign

FIXED-1  Parenthesized property as an implication consequent.  `4e943c5f`
    `a |-> (b throughout c)` had no parse at all and desynced the parser past
    the enclosing generate block's `end`, so later correct module items were
    reported as "Invalid module item". OpenTitan writes its reset and
    secure-wipe checkers this way. Five-IP assertion diagnostics 277 -> 186.

FIXED-2  Non-blocking assignment of an unpacked-array pattern.  `4cb5e9ed`
    `q <= '{...}`. One root, two faces: a whole-array l-value ABORTED the code
    generator; a SLICE l-value did not abort — it stored a zero in the first
    word, dropped the rest, and ran. `m[1] <= '{8'hA1,8'hB2,8'hC3}` left all
    three words at zero while the blocking spelling beside it produced the right
    values. otbn RTL went from exit 134 to a 22.8 MB image.

FIXED-3  Element type on a packed-array element l-value.  `9254f15c`
    `cmd_info_t [N-1:0] cmd_info; cmd_info[i] = '{...}` was SILENTLY DISCARDED —
    spi_device's whole command table stayed zero in the compiled model.

FIXED-4  Array parameter element lost its packed dimensions.  `81793a2d`
    `localparam logic [1:0][5:0] P [2]; P[1][1]` returned bit 1 instead of the
    upper 6-bit element. Exit 0, no diagnostic; the identical plain variable was
    correct. Dimensions were taken from the per-element INFERRED type.

FIXED-5  Run-time element index followed by further selects.  `17d23d8e`
    `TpmReturnByHwAddr[i][11:2]` (spi_tpm.sv:786). Routed into
    `param_select_packed_`. Closed spi_device.

FIXED-6  N-dimensional unpacked array parameters.  `bb5fb521`
    `localparam int PiRotate [5][5]`. Also converted two ABORTS (untyped array
    parameter, same-scope array propagation — both `t-dll.cc:530`) and two
    silent-`x` cases (self-referential and cyclic array parameters) into named
    errors. Does NOT close kmac; see OPEN-7.

FIXED-7  Unknown package in an import.  `fbd32f4c`
    Was a bare `syntax error` blamed on the enclosing construct, and FATAL at
    package scope ("I give up"), suppressing every other diagnostic in the run.
    This is what made the OpenTitan DV dependency chain unreadable.

FIXED-8  Compile-progress zero fallbacks.  (in PR #147)
    Six sites answered "I do not handle this" by emitting a zero and letting the
    compile SUCCEED. All now count an error. Making them loud immediately
    exposed FIXED-3.

---

## 3. Open — priority 1 (silent wrong result)

OPEN-1  Non-`ref` input formals of queue/darray type ALIAS the caller.
    REPRODUCED BY THE LEAD. `function automatic int f(int m [$]); m[0]=32'hff;`
    called with a queue whose `q[0]` is `11` leaves the CALLER's `q[0]` at `ff`.
    Same for dynamic arrays. IEEE 1800-2017 13.5.1 requires pass-by-value.
    Exit 0, no diagnostic. UVM passes queues into functions constantly, so the
    exposure is wide. Same class as the struct copy aliasing already fixed in
    Recovery Campaign 3; `draw_eval_object_value_copy` in tgt-vvp/stmt_assign.c
    is the analogous helper.

OPEN-2  A 1-D array parameter through a module port override reads back `x`.
    SUBAGENT REPORT, NOT INDEPENDENTLY REPRODUCED. `#(.P(Q))` where Q is an
    array parameter. Claimed root cause: `NetScope::evaluate_parameters`
    (net_design.cc ~1436) recurses into `children_` BEFORE evaluating its own
    `parameters`, so when the child expands `P` the parent's `Q[0]` does not
    exist yet and the copy loop creates ZERO elements. Exit 0, warning only.
    Self-referential (`int A[3] = A;`) and cyclic (`A=B; B=A;`) forms were the
    same silent `x` — those two are fixed by FIXED-6.

OPEN-3  2-state / real / string unpacked arrays in `automatic` scopes are not
    per-frame.  SUBAGENT REPORT, NOT INDEPENDENTLY REPRODUCED. `vvp/array.cc`
    `compile_var_array` (4-state) branches on `is_automatic()` and uses
    `vvp_vector4array_aa`; `compile_var2_array` and `compile_real_array` have no
    such branch and there is no `_aa` sibling of `vvp_darray_*`. Claimed: a
    recursive automatic function with a local `int m[4]` sees the inner frame's
    writes. `logic [31:0] m[4]` is fine. Verify before acting.

OPEN-4  A whole-array reference to an unpacked array PARAMETER elaborates to a
    ZERO-WIDTH CONSTANT ZERO.  Latent. Array parameters are stored as separate
    scalars `"A2X[0]".."A2X[7]"` with no array object (net_scope.cc:385).
    Today the only thing catching it is `assert(ivl_signal_dimensions(port)==0)`
    at tgt-vvp/draw_ufunc.c:30 — and asserts vanish under NDEBUG. If it ever
    reached codegen, `aes_mvm` would return `8'h00` for every input and AES
    would silently encrypt to garbage. Blocks OPEN-5.

---

## 4. Open — priority 4 (missing legal construct, refused loudly)

OPEN-5  Subroutine ports with unpacked dimensions.  aes_pkg.sv:685.
    The refusal is elab_sig.cc:1730, unconditional on
    `NetNet::unpacked_dimensions()!=0`, and fires on the DECLARATION alone.
    FIVE gates sit behind it:
      1. elab_sig.cc:1730 — the refusal;
      2. elab_expr.cc ~9838 `elaborate_arguments_` — typed r-value path has no
         whole-array form ("Array a needs an array index here");
      3. elaborate.cc ~9372 `elaborate_build_call_` — copy-in is a scalar assign;
      4. tgt-vvp/draw_ufunc.c:30 — `assert(ivl_signal_dimensions(port)==0)`;
      5. tgt-vvp/vvp_scope.c:2465 `draw_lpm_ufunc` — the `.ufunc` LPM node wires
         ONE NEXUS PER FORMAL and its port list can only name a plain variable.
    The RETURN direction already works (`draw_ufunc_uarray`, draw_ufunc.c:865,
    hooked from stmt_assign.c:3257); an input formal is its mirror.
    THE AES CALL SITE IS A CONTINUOUS ASSIGNMENT WITH A PARAMETER ACTUAL, so it
    needs gate 5 AND OPEN-4. Lifting gate 1 alone unblocks procedural calls —
    all of UVM and most testbench code — but does NOT fix aes.
    `unpacked_dimensions()` is 0 for darray/queue/assoc, which is why those work.

OPEN-6  Array slice as a port connection.  aes_ghash.sv:351.
    ATTEMPTED AND REVERTED by the lead rather than ship a silent wrong result.
    Refusal is `PEIdent::elaborate_unpacked_net` (elab_net.cc ~1370), which
    refuses any non-empty index tail.
    An ALIAS works for INPUT ports and is correct: unpacked array nets carry one
    pin per word, so a NetNet with the sub-array's dims whose pins `connect()`
    to `reg->pin(base+k)` reads right (verified `res = 3 c`).
    It FAILS for OUTPUT ports — silently produces `x`, exit 0. Root cause found:
    elaborate.cc ~2367 coerces a REG expression net to UNRESOLVED_WIRE so a
    structural driver can reach it; with an alias that coercion lands on the
    TEMPORARY and the real variable never receives the nexus value. Whole-array
    (unsliced) output ports DO work (verified `5 a`).
    The OpenTitan shape is an INPUT port with a genvar index. Supporting input
    and refusing output BY NAME is acceptable — but the refusal must live at the
    caller in elaborate.cc, which is the only place that knows the direction.

OPEN-7  Ternary over whole unpacked arrays in a continuous assignment.
    kmac_core.sv:252 and :260, run-time condition, one arm is `'{'d0}`.
    `a56ef0b9` handled the CONSTANT-condition BLOCKING case via
    `see_through_const_ternary_`. Entry point here is
    `elaborate_unpacked_array` (elaborate.cc ~1403), which accepts a PEIdent or
    a PEAssignPattern and errors on anything else. There is no run-time mux over
    a whole unpacked array in the netlist; a per-word mux is expressible because
    array nets carry one pin per word.

OPEN-8  Array-parameter element followed by a struct member select.
    kmac_app.sv:297-303 — `AppCfg[arb_idx].session_cfg.mode`, five consecutive
    lines, ONE construct. Error text: "Parameter name AppCfg[arb_idx] can't have
    member names". A member select differs from a packed index: the member name
    must resolve to a bit offset and width in the element's packed struct type.

OPEN-9  `[*0]` empty-match repetition is rejected and the assertion DROPPED.
    Boundary measured: the zero lower bound only; `[*1:2]`, `[*1:$]` and `[*2]`
    all work.

---

## 5. Open — architectural

OPEN-10  `PCondit::elaborate` still ASSUMES A CONDITION FALSE when it fails to
    elaborate, deleting the then-branch and compiling the else-branch in its
    place. The in-tree note says it must become a hard error once its two UVM
    dependents elaborate. MEASURED: they do not. Removing it fails the ENTIRE
    229-test UVM suite at exactly the two lines the note names —
    `uvm_comparer.svh:638` (nested associative index plus member access) and
    `uvm_driver.svh:100` (`seq_item_port.size<1`, an unparenthesized
    method-result compare). Those two expression forms are the work that
    unblocks it.
    An earlier scan reported zero UVM hits; that scan compiled `tests/*.sv`
    WITHOUT `uvm_pkg.sv`, so the library was never elaborated. The scan was
    wrong, not the note.

OPEN-11  Recursive `property_expr` representation. `sva_property_t` holds the
    antecedent as a flat `std::vector<sva_seq_step_t>` and the consequent in a
    single `seq` field, so neither can carry a tree or a nested property. This
    is the single largest SVA item — 82+ of the 186 diagnostics.

---

## 6. Traps already paid for — do not re-learn these

TRAP-1  Array dimension direction. Any dimension handed to
    `normalize_variable_base` / `norm_const` must be `netrange_t(hi, lo)` with
    hi=max, lo=min — never the declared `(left, right)`. Element tables are laid
    out ASCENDING from the low index whatever the declaration direction, and
    those functions branch on `msb < lsb`, so the declared pair SILENTLY
    REVERSES `[1:4]` and `[0:3]`. No diagnostic. A build mutated this way still
    compiles at exit 0.

TRAP-2  Oracles that cancel. A regression whose expected values come from a
    flat array oracle can pass while both sides are wrong, because the direction
    mutation reverses the oracle too. Expected values must be ARITHMETIC in the
    loop variables, or hand-computed. This actually happened during the
    `sv_uparam_multi_dim` work.

TRAP-3  Alias vs copy on output ports. See OPEN-6 — the REG -> UNRESOLVED_WIRE
    coercion lands on the temporary, and the real variable reads `x`.

TRAP-4  A shell pipeline that greps for `": error"` and declares success when
    the grep is empty reports real failures as passes. This produced five bogus
    "reconstruction passed" claims earlier in the campaign. Always capture full
    output AND exit status.

TRAP-5  Never run `ivtest/vvp_reg.pl` and `ivtest/vpi_reg.pl` concurrently —
    both compile to `./vsim` in a shared directory and clobber each other,
    producing dozens of phantom failures.

TRAP-6  Counting `: error:` lines is not a status check. A compiler abort prints
    no such line, which is how otbn was recorded as "0 errors" while aborting.

---

## 7. Gate ladder

Run before any merge; a change is not done until all of it is green.

    ivtest sweep        cd ivtest && perl vvp_reg.pl          3310 total
    negative suite      bash tests/negative/run_negative.sh   110
    sva_nfa dual-run    bash tests/sva_nfa/run.sh             46
    UVM regression      bash .github/uvm_test.sh             229

Bison conflict baseline: **497 shift/reduce, 1162 reduce/reduce**, and three
rules useless-in-parser. Any grammar change must leave all of that unchanged.
