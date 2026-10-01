# Implicit object-method lookup and OpenTitan smoke — L108

FOCUSED_TESTED; required broad batch qualification remains pending.
IEEE 1800-2017 and2023 8.2,8.4,8.10,8.11,8.18,8.25.1.

A dotted object-property call could be classified as an unrelated parameterized
class scope before ordinary receiver lookup ran. PCallTask now retains explicit
scope-operator provenance through parser actions, copies and expression
conversions. Early static dispatch uses that provenance; existing receiver
lookup handles dotted calls. Static-method checks use the actual declaration
qualifier, and inherited local-property checks use the declaring class.
Temporary traces and speculative expression/receiver recovery were removed.
No grammar productions changed; the Bison conflict signature is unchanged
(562 shift/reduce,1122 reduce/reduce).

Both edition modes pass six runtime positives and ten negative cases, covering
implicit/explicit receivers, package-name collisions, inherited/protected and
indexed properties, lexical/module/static-local object shadowing, real scoped
specialization and static/local access rejection. The focused legacy and JSON
harnesses each pass16. Neighbors pass89 legacy and61 JSON; not all older legacy
cases have JSON entries. Broad qualification remains separate.

The fresh original-UVM-1.2 Darjeeling debug-crossbar `xbar_smoke` replay passes
on this candidate: **190 requests,380 scoreboard items,zero UVM warnings,
errors or fatals**, no reported semantic debt, and normal UVM completion.
The pinned unmodified sources retain response joins, pending-request deletion,
expected/actual counts, final empty-queue and FIFO checks. Report-catcher counts
show no demoted/caught errors. This is one pinned core/default run in g2012,
not a full OpenTitan or IEEE1800.2/edition-wide qualification.

The [validation record](2026-09-15_implicit_property_method_lookup_validation.json)
contains source/tool fingerprints, exact commands, the runtime log and the
failed-attempt history. Caliptra configuration and runtime findings are recorded
separately; no upstream application or UVM sources were changed.
