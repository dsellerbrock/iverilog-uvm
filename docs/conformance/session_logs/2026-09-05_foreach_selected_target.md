# Selected-member foreach target binding

Procedural `foreach(devices[i].ranges[j])` declared a new `i` and traversed every
device, even inside an enclosing foreach that had already selected a device.
In an unmodified OpenTitan xbar run, address 0x2309 was consequently assigned to
rv_dm__dbg instead of soc_dbg_ctrl__jtag; the later scoreboard comparison exposed
the wrong queue assignment. A standalone two-device reducer reproduces this.
Changing its prefix to `(i)` is an external diagnostic control, never an
application workaround.

## IEEE contract and implementation

IEEE 1800-2017 and IEEE 1800-2023 12.7.3 and Annex A.6.8 describe the selected
array followed by its terminal loop-variable list. Both editions 23.7 distinguish
member selections rooted in data objects from hierarchical names. Ordinary
indexing is covered by 2017 7.4.6 and 2023 7.4.5. A comma-separated prefix list
is not an ordinary index expression. Package-use recording follows both editions
26.3. The licensed IEEE texts supply these requirements; Slang supplies only
independent syntax/elaboration comparisons.

The parser still needs the identifier-prefix carrier: deleting it preserves
conflict totals but removes the member-dot transition after an identifier has
reduced to loop_variables. Its action now records the prefix with pform_new_ident
before the implicit scope/body can affect wildcard imports, attaches the selected
index to the existing path, declares only terminal variables, and emits one
PForeach. Invalid prefix lists are hard errors; unresolved selectors cannot turn
into zero-iteration success. No runtime, ABI, scheduler or application source
changes are part of this patch.

Native source review caught an initial raw-PEIdent import bypass; the installed
version uses the existing identifier factory at the original header use point.
Ownership follows the neighboring expression-prefix carrier. Bison 3.8.2 reports
541 shift/reduce and 1122 reduce/reduce conflicts; all 5,871 normalized state
sections match the baseline, SHA-256
ee12a7fdd5aa2a8b4d0e1257f3766567f9cef1537ce928e85c86fa8ba411cd12.

## Regression evidence

Five paired families add ten entries per legacy/JSON main manifest: selected
member values plus undeclared, comma-list, ambiguous-import and late-declaration
negative cases. The positive family covers fixed arrays, queues, enclosing
iterators, function arguments, a wildcard selector's only use, ordinary
multidimensional foreach and terminal shadowing. The corrected old
sv_foreach_hierarchical_dual_dim remains registered and retains its six original
value assertions; selected-row counts and untouched sentinels now reject the
incorrect extra iteration.

Both editions accept the positive fixtures in Slang; old installed Icarus fails
the value/visit checks and incorrectly accepts undeclared/comma prefixes. Its
old import-negative failures report duplicate invented declarations instead of
the required import diagnostics. After the fix, both edition modes pass all
positive checks and reject all four negative families with reviewed diagnostics.
The focused legacy harness passes 14/14 and JSON passes 10/10. JSON edition pairs
compile the same base fixture with different language modes, keeping the exact
source-path diagnostic gold stable; legacy uses its required filename wrappers.
The first JSON attempt exposed only wrapper path-prefix differences in four
negative gold comparisons; the direct base-fixture configuration resolves them.

Native ARM64 parse.o build, serial make and make install pass with Homebrew
Bison 3.8.2 and the 300-second per-process CPU guard. Installed tools are first on
PATH. Source/install fingerprints and make-q for parse.o are verified. The full
integrated gate passes: legacy 4641/4646, zero failed, two not implemented and
three expected failures, with a clean name diff; JSON 1535/0; VPI 103/103;
negative 149/0; runtime invariants including state foreach 15/15; real-DPI UVM
355 passed, zero failed and zero skipped. The final marker is
FOREACH_SELECTED_GATE_DONE=0. Fresh OpenTitan and Caliptra censuses are running
against the same frozen compiler; their per-core comparison remains pending.

Evidence under evidence/xbar-zero-traffic-after255-arm64-20260904 includes
foreach-selected-build1-result.json, foreach-selected-build1-fingerprints.json,
foreach-selected-final-gate1-result.json,
foreach-selected-direct-green1-results.json, foreach-selected-registration-audit.json,
foreach-selected-v2-code-review.md, bison-foreach-standard-plan2/proposed-v2-comparison.json,
and the retained foreach-selected-candidates-v2/final-candidates-red-results.json.

## Remaining boundaries

Selected associative member index typing still loses string/enum/wide key
information in existing declaration-time inference. Research probes retain the
zero-iteration string-key failure for both bare and parenthesized selected
prefixes, alongside a passing direct-handle control. A separate candidate is
being developed; it is not part of this increment and is not a passing test.
A same-name prefix/terminal-iterator research probe has unresolved scope
expectations and is not registered as a conformance test.

The separately completed enum-build baseline is OpenTitan 203 PASS with eight
xbar runtime timeouts, Caliptra static 52 PASS / ICARUS_GAP 0. No new application
count is claimed before the selected-build per-core comparison completes.
