// Regression: parameterized-class VARIABLE / HANDLE declarations must
// specialize the class, exactly as an `extends C#(args)` clause does.
//
// Root cause (docs/conformance/m7_stress_findings_2026-07-18.md "Finding 4"):
// a declaration like `box #(plain) b;` reaches pform_make_modgates through
// the no-port module-instantiation shape. When that shape is reinterpreted
// as a variable declaration the `#(plain)` parameter overrides were dropped,
// so the GENERIC netclass (every type parameter at its default) was bound.
// A member typed by a type-parameter therefore kept its default type (int),
// and a method call on it found no class and fell into the "Enable of
// unknown task" no-op (later a vthread pop_prop_val assertion at run time).
//
// Two fixes are exercised here:
//   1. pform.cc threads the `#(...)` overrides onto the reinterpreted
//      variable's typeref so the handle specializes.
//   2. elab_scope.cc seeds VIRTUAL method overrides of a specialized class
//      so virtual dispatch through a parameterized base handle resolves to
//      the derived override instead of the base stub.
//
// Self-checking: prints "PASS" only if every sub-check holds; otherwise
// prints "FAIL ..." with the failing case.
`timescale 1ns/1ns

class Plain;
  int s;
  task g(output int t); t = s; endtask
endclass

class Box #(type IMP = int);
  IMP m;
  task run(output int t); m.g(t); endtask
endclass

class Item;
  int unsigned tag;
  function new(int unsigned t = 0); tag = t; endfunction
endclass

class SqrIfBase #(type REQ = int);
  virtual task get_next(output REQ t); /* base stub: leaves t unset */ endtask
endclass

class Sequencer #(type REQ = int) extends SqrIfBase #(REQ);
  REQ stash;
  virtual task get_next(output REQ t); t = stash; endtask
endclass

class ImpC #(type REQ = int, type IMP = int) extends SqrIfBase #(REQ);
  IMP m_imp;
  virtual task get_next(output REQ t); m_imp.get_next(t); endtask
endclass

module m1b_typeparam_member_call_test;

  int errors = 0;

  initial begin
    // Shape 1: type-parameter-typed member reached through a specialized
    // handle declaration `Box#(Plain) b`. This is the task's minimal
    // Finding-4 repro.
    begin
      automatic int got;
      automatic Plain p = new;
      automatic Box#(Plain) b = new;
      p.s = 9;
      b.m = p;
      b.run(got);
      if (got !== 9) begin
        errors++;
        $display("FAIL shape1: type-param member call got=%0d exp=9", got);
      end
    end

    // Shape 2: a base handle to a specialized subclass dispatches virtually
    // to the subclass override, not the base stub.
    begin
      automatic Item got;
      automatic Sequencer#(Item) sqr = new;
      automatic SqrIfBase#(Item) base_h;
      sqr.stash = new(42);
      base_h = sqr;            // base handle -> derived specialized instance
      base_h.get_next(got);    // virtual dispatch must reach Sequencer::get_next
      if (got == null || got.tag !== 42) begin
        errors++;
        $display("FAIL shape2: virtual dispatch through parameterized base handle");
      end
    end

    // Shape 3: a subclass that both EXTENDS a parameterized base and has a
    // type-parameter-typed member; a direct call chains through the member.
    begin
      automatic Item got;
      automatic Sequencer#(Item) sqr = new;
      automatic ImpC#(Item, Sequencer#(Item)) imp = new;
      sqr.stash = new(7);
      imp.m_imp = sqr;
      imp.get_next(got);       // ImpC::get_next -> m_imp.get_next
      if (got == null || got.tag !== 7) begin
        errors++;
        $display("FAIL shape3: type-param member call inside extending subclass");
      end
    end

    if (errors == 0)
      $display("PASS");
    else
      $display("FAIL: %0d sub-check(s) failed", errors);
  end

endmodule
