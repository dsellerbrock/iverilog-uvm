// IEEE 1800-2023 13.5.3: an omitted argument's default is evaluated in
// the scope containing the subroutine declaration each time the default is
// used. IEEE 1800-2023 25.9: one virtual-interface variable can represent
// different interface instances at different times. Exercise both rules
// together without relying on a deferred/late interface-dispatch path.

package vif_default_decl_pkg;
  typedef enum logic [1:0] {
    ModeZero     = 2'd0,
    ModeExpected = 2'd2
  } mode_e;

  int counter = 0;

  function automatic int next_stamp();
    counter += 1;
    return counter;
  endfunction
endpackage

interface vif_default_leaf_if;
  import vif_default_decl_pkg::*;

  localparam int LOCAL_STEP = 10;
  logic [31:0] local_seed = 0;
  int task_a = 0;
  int task_b = 0;
  int func_a = 0;
  int func_b = 0;
  logic [1:0] task_mode = ModeZero;
  logic [1:0] func_mode = ModeZero;
  int task_stamp = 0;
  int func_stamp = 0;

  task automatic mark_task(
      int a = local_seed + LOCAL_STEP,
      int b = a + 1,
      mode_e mode = ModeExpected,
      int stamp = vif_default_decl_pkg::next_stamp());
    task_a = a;
    task_b = b;
    task_mode = mode;
    task_stamp = stamp;
  endtask

  function automatic void mark_func(
      int a = local_seed + LOCAL_STEP,
      int b = a + 1,
      mode_e mode = ModeExpected,
      int stamp = vif_default_decl_pkg::next_stamp());
    func_a = a;
    func_b = b;
    func_mode = mode;
    func_stamp = stamp;
  endfunction
endinterface

// Keep the direct leaf instances below a module wrapper. This forces method
// lookup and dynamic dispatch to inspect the hierarchy instead of assuming an
// interface instance is an immediate child of the simulation root.
module vif_default_wrapper;
  vif_default_leaf_if direct_i();
endmodule

interface vif_default_outer_if;
  vif_default_leaf_if nested();
endinterface

package vif_default_caller_pkg;
  class vif_default_decl_runner;
    virtual vif_default_leaf_if direct_vif;
    virtual vif_default_outer_if outer_vif;

    // Each method below contains one call site per interface method. Rebinding
    // the handle and calling run_direct() again must select a new receiver.
    task run_direct();
      direct_vif.mark_task();
      direct_vif.mark_func();
    endtask

    task run_nested();
      outer_vif.nested.mark_task();
      outer_vif.nested.mark_func();
    endtask
  endclass
endpackage

module sv_vif_default_decl_scope;
  import vif_default_caller_pkg::*;

  vif_default_wrapper direct0();
  vif_default_wrapper direct1();
  vif_default_outer_if outer0();
  vif_default_outer_if outer1();
  vif_default_decl_runner runner;

  initial begin
    runner = new;

    direct0.direct_i.local_seed = 1;
    direct1.direct_i.local_seed = 20;
    outer0.nested.local_seed = 30;
    outer1.nested.local_seed = 40;

    runner.direct_vif = direct0.direct_i;
    runner.run_direct();
    runner.direct_vif = direct1.direct_i;
    runner.run_direct();

    // The statically named nested interface must still be selected below the
    // dynamically selected outer instance. outer0 is deliberately uncalled.
    runner.outer_vif = outer1;
    runner.run_nested();

    if (direct0.direct_i.task_a != 11 || direct0.direct_i.task_b != 12
        || direct0.direct_i.task_mode !== 2
        || direct0.direct_i.task_stamp != 1
        || direct0.direct_i.func_a != 11 || direct0.direct_i.func_b != 12
        || direct0.direct_i.func_mode !== 2
        || direct0.direct_i.func_stamp != 2
        || direct1.direct_i.task_a != 30 || direct1.direct_i.task_b != 31
        || direct1.direct_i.task_mode !== 2
        || direct1.direct_i.task_stamp != 3
        || direct1.direct_i.func_a != 30 || direct1.direct_i.func_b != 31
        || direct1.direct_i.func_mode !== 2
        || direct1.direct_i.func_stamp != 4
        || outer1.nested.task_a != 50 || outer1.nested.task_b != 51
        || outer1.nested.task_mode !== 2 || outer1.nested.task_stamp != 5
        || outer1.nested.func_a != 50 || outer1.nested.func_b != 51
        || outer1.nested.func_mode !== 2 || outer1.nested.func_stamp != 6
        || outer0.nested.task_a != 0 || outer0.nested.task_b != 0
        || outer0.nested.func_a != 0 || outer0.nested.func_b != 0
        || outer0.nested.task_mode !== 0 || outer0.nested.func_mode !== 0
        || outer0.nested.task_stamp != 0 || outer0.nested.func_stamp != 0
        || vif_default_decl_pkg::counter != 6) begin
      $display("FAILED direct0=%0d/%0d,%0d/%0d direct1=%0d/%0d,%0d/%0d",
               direct0.direct_i.task_a, direct0.direct_i.task_b,
               direct0.direct_i.func_a, direct0.direct_i.func_b,
               direct1.direct_i.task_a, direct1.direct_i.task_b,
               direct1.direct_i.func_a, direct1.direct_i.func_b);
      $display("FAILED nested0=%0d/%0d,%0d/%0d nested1=%0d/%0d,%0d/%0d counter=%0d",
               outer0.nested.task_a, outer0.nested.task_b,
               outer0.nested.func_a, outer0.nested.func_b,
               outer1.nested.task_a, outer1.nested.task_b,
               outer1.nested.func_a, outer1.nested.func_b,
               vif_default_decl_pkg::counter);
    end else begin
      $display("PASSED");
    end
    $finish(0);
  end
endmodule
