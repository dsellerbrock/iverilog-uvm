// ICE reproducer (M1C-1): `foreach' over a RUNTIME-SIZED array inside the
// constructor of a class declared at $unit scope aborts the compiler:
//
//   assert: elaborate.cc:11284: failed assertion idx_sig
//
// Compile with: iverilog -g2012 -o /dev/null <this file>
//
// What was established while minimizing it:
//
//   * Only the CONSTRUCTOR. The identical body in any other method
//     (`function void init()') elaborates and runs correctly.
//   * Only a RUNTIME-SIZED target -- a dynamic array or a queue, whether
//     it is a class property or a method local. A fixed-size array
//     property takes the compile-time-bounds path and is fine.
//   * Only at $unit scope. The same class declared inside a module works.
//   * The block scope exists; the loop variable does not. At the failure
//     point `$unit.H.new.$ivl_foreach0' is a child of the constructor
//     scope, and no signal `i' exists in it, in the constructor scope, in
//     the class scope, or in $unit. `PFunction::elaborate_sig' runs once
//     for the constructor (elab_stage 1 -> 2) and its walk reaches the
//     block -- `PBlock::elaborate_sig' does not report a missing child
//     scope -- so `elaborate_sig_wires_' ran against an EMPTY wire list.
//   * The PFORM SIDE IS CORRECT. Instrumenting
//     `pform_make_foreach_declarations' shows the loop variable being
//     declared into the pushed PBlock in BOTH the failing constructor and
//     the working non-constructor case ("into lexical_scope=... kind=PBlock,
//     scope now has 1 wires"). So the declaration is where it belongs and
//     the loss is on the elaboration side.
//
//   * NOT two NetScope trees. Logging the scope pointer in
//     `netclass_t::elaborate_sig' and again at the failing
//     `elaborate_runtime_array_' gives the SAME NetScope object, at
//     elab_stage 1 with a statement attached -- so the signature pass runs
//     on exactly the scope the body is later elaborated against.
//   * THE SIGNATURE WALK IS IDENTICAL to the working case. Tracing
//     `PBlock::elaborate_sig' shows both the failing constructor and the
//     working control descending into `$ivl_foreach0' with wires=1:
//
//       DBG blk in $unit.H.new       name=$ivl_foreach0 wires=1 stmts=1
//       DBG blk in $unit.Holder.init name=$ivl_foreach0 wires=1 stmts=1
//
//     So `elaborate_sig_wires_' is called on the right scope, with the
//     right wire, in both -- and only one of them ends up with a signal.
//
// The next step is therefore INSIDE `elaborate_sig_wires_' /
// `PWire::elaborate_sig' for that one wire: log why the NetNet is not
// created (or is created and then not findable) when the enclosing
// function is a constructor. The loop variable's type is a
// `foreach_index_type_t', which resolves through
// `resolve_class_handle_placeholder_type_weak_' -- that returns 0 for a
// non-class index type, and whether the caller treats 0 as "skip this
// wire" is the first thing to check. The assertion at elaborate.cc:11284
// is the symptom, not the defect.
//
// Uncomment either variant to reproduce; both abort.

class H;
  int d[];                  // property variant
  function new();
    int q[];                // local variant
    d = new[4];
    q = new[4];
    foreach (d[i]) d[i] = i;   // <-- aborts here
    foreach (q[i]) q[i] = i;   // <-- and here
  endfunction
endclass

// Control: the same body in a non-constructor method is correct.
class H_ok;
  int d[];
  function void init();
    d = new[4];
    foreach (d[i]) d[i] = i;
  endfunction
endclass

module main;
  H    x;
  H_ok y;
  initial begin
    y = new();
    y.init();
    $display("control ok d[2]=%0d", y.d[2]);
    x = new();
    $display("x.d[2]=%0d", x.d[2]);
  end
endmodule
