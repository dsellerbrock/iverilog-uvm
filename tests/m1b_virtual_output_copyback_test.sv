// Regression: a virtual task with an `output` argument, dispatched through
// a base-class handle, must copy its output back even when the call is
// nested inside another task whose own `output` formal is the destination
// (the UVM sequencer/driver `get_next_item(req)` "port copy-back" shape).
//
// Runtime root cause (vvp/vthread.cc do_join): a virtual call runs its
// override in a separate dispatch context that is NOT on the caller's write
// stack. do_join's pop-push looked for the OVERRIDE scope's frame to pop off
// the write stack, found nothing (only the base call-site `%alloc` frame is
// stacked there), and left that base frame at the write head. The enclosing
// task's own `output` store then landed in the base frame instead of its own,
// so the returned handle was silently dropped (caller saw null). The fix pops
// the base (call-site) scope frame for a dynamically dispatched child, exactly
// as the non-virtual call path does.
//
// This defect is NOT parameterization-specific; both a plain and a
// parameterized shape are checked. Prints "PASS" only if every check holds.
`timescale 1ns/1ns

// ---- Plain (non-parameterized) shape ----
class item_p;
  int unsigned tag;
  function new(int unsigned t = 0); tag = t; endfunction
endclass

class base_p;
  virtual task get_next(output item_p t); /* base stub leaves t unset */ endtask
endclass

class deriv_p extends base_p;
  item_p stash;
  virtual task get_next(output item_p t); t = stash; endtask
endclass

class port_p;
  base_p m_if;                                   // base handle
  task get_next(output item_p t); m_if.get_next(t); endtask  // output copy-back through virtual dispatch
endclass

// ---- Parameterized shape (the RAL sequencer/driver arrangement) ----
class base_g #(type REQ = int);
  virtual task get_next(output REQ t); endtask
endclass

class seq_g #(type REQ = int) extends base_g #(REQ);
  REQ stash;
  virtual task get_next(output REQ t); #1; t = stash; endtask
endclass

class imp_g #(type REQ = int, type IMP = int) extends base_g #(REQ);
  IMP m_imp;
  virtual task get_next(output REQ t); m_imp.get_next(t); endtask
endclass

class port_g #(type REQ = int);
  base_g #(REQ) m_if;
  task get_next(output REQ t); m_if.get_next(t); endtask
endclass

module m1b_virtual_output_copyback_test;
  int errors = 0;

  initial begin
    // Plain shape
    begin
      automatic item_p got;
      automatic deriv_p d = new;
      automatic port_p  p = new;
      d.stash = new(42);
      p.m_if = d;
      p.get_next(got);
      if (got == null || got.tag !== 42) begin
        errors++;
        $display("FAIL plain: virtual output copy-back through wrapper task");
      end
    end

    // Parameterized shape: port -> base handle -> imp override -> seq member
    begin
      automatic item_p got;
      automatic seq_g #(item_p)               s = new;
      automatic imp_g #(item_p, seq_g#(item_p)) imp = new;
      automatic port_g #(item_p)              port = new;
      s.stash = new(7);
      imp.m_imp = s;
      port.m_if = imp;
      port.get_next(got);
      if (got == null || got.tag !== 7) begin
        errors++;
        $display("FAIL param: RAL-shape virtual output copy-back");
      end
    end

    if (errors == 0) $display("PASS");
    else             $display("FAIL: %0d sub-check(s) failed", errors);
  end
endmodule
