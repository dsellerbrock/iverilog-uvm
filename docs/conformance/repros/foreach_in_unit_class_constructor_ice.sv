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
//     The declaration `pform_make_foreach_declarations' builds therefore
//     lands in some lexical scope other than the pushed block.
//
// So the fix is on the pform side (where the foreach block scope is
// pushed for a $unit class constructor), not in the elaborator, and the
// assertion at elaborate.cc:11284 is the symptom.
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
