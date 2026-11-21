module coverage_one;
  task automatic hit(input bit pass);
    assert (pass) else ;
  endtask
endmodule

module coverage_delay(input bit clk, outcome, disabled, output int actions, failures);
  p: assert property (@(posedge clk) disable iff (disabled) 1'b1 |-> ##1 outcome)
       actions++;
     else failures++;
endmodule

module coverage_vacuous #(parameter int N = 2)(input bit clk, disabled);
  bit destination, never;
  assume property (@(posedge clk) disable iff (disabled) 1'b0 |-> 1'b0) else ;
  cover property (@(posedge clk) disable iff (disabled)
                  never |=> @(posedge destination) 1'b0);
  cover property (@(posedge clk) disable iff (disabled) never[*N] |-> 1'b0);
endmodule

module coverage_procedural(input bit clk);
  sequence s;
    @(posedge clk) 1'b1;
  endsequence
  initial begin
    assert property (s) else $fatal(1, "procedural failure");
    expect (@(posedge clk) 1'b1) else $fatal(1, "expect failure");
  end
  cover property (@(posedge clk) s.triggered);
  restrict property (@(posedge clk) 1'b1);
endmodule

module coverage_deferred;
  initial begin : queued
    assume #0 (1) ;
    cover final (1) ;
    flush_observed: assert #0 (1) $error("flushed Observed action");
    flush_final: cover final (1) $error("flushed Postponed action");
    disable flush_observed;
    disable flush_final;
  end
endmodule

module coverage_leaf;
  initial #1 cover (1);
endmodule

module coverage_family;
  initial begin : lexical
    #1 assert (1);
  end
  for (genvar i = 0; i < 2; i++) begin : g
    coverage_leaf child();
    if (i == 0) begin : selected
      initial #1 assume (1);
    end
  end
  module slot;
    initial #1 cover (1);
  endmodule
  slot inst();
endmodule

module coverage_other;
  module slot;
    initial #1 cover (1);
    initial #1 assume (1);
  endmodule
  slot inst();
endmodule

module coverage_tree #(parameter int DEPTH = 1);
  initial #1 assert (1);
  if (DEPTH > 0) begin : g
    coverage_tree #(DEPTH - 1) child();
  end
endmodule

module coverage_empty;
endmodule

module coverage_always(input bit clk, value);
  assert property (@(posedge clk) always [0:2] value) else ;
endmodule

module coverage_eventually(input bit clk, value);
  assert property (@(posedge clk) eventually [0:2] value) else ;
endmodule

module coverage_abort(input bit clk, accept);
  assert property (@(posedge clk) sync_accept_on(accept) 1'b0) else ;
endmodule

program coverage_reactive(input bit clk, inspect, output int observations);
  initial forever begin
    @(posedge clk);
    if (inspect) begin
      if ($coverage_get(20, 10, $root.issue3975_assertion_coverage.delay_checker) != 1)
        $fatal(1, "success unavailable in Reactive");
      if ($coverage_control(2, 20, 10, $root.issue3975_assertion_coverage.delay_checker) != 1)
        $fatal(1, "Reactive RESET failed");
      observations++;
    end
  end
endprogram

module issue3975_assertion_coverage;
  localparam int START = 0, STOP = 1, RESET = 2, CHECK = 3,
                 MODULE = 10, HIER = 11, ASSERTION = 20;

  bit clk, outcome = 1, disabled, vac_disabled = 1, proc_clk, inspect;
  bit temporal_clk, yes = 1;
  int actions, failures, observations;
  string definition = "coverage_family.slot";

  coverage_one one();
  coverage_delay delay_checker(clk, outcome, disabled, actions, failures);
  coverage_vacuous vac(clk, vac_disabled);
  coverage_procedural proc(proc_clk);
  coverage_deferred deferred_checks();
  coverage_family left(), right();
  coverage_other other();
  coverage_tree tree();
  coverage_empty empty();
  coverage_reactive observer(clk, inspect, observations);
  coverage_always finite(temporal_clk, yes);
  coverage_eventually eventual(temporal_clk, yes);
  coverage_abort accepted(temporal_clk, yes);

  task automatic check(input bit ok, input string message);
    if (!ok) $fatal(1, "%s", message);
  endtask

  task automatic tick;
    #1 clk = 1;
    #1 clk = 0;
  endtask

  task automatic temporal_tick;
    #1 temporal_clk = 1;
    #1 temporal_clk = 0;
  endtask

  initial begin
    check($coverage_get_max(ASSERTION, HIER, $root) == 28, "load-time root maximum");
    check($coverage_get_max(ASSERTION, MODULE, delay_checker) == 1, "initial clocked maximum");
    check($coverage_get(ASSERTION, HIER, $root) == 0, "initial numerator");

    one.hit(1);
    check($coverage_control(CHECK, ASSERTION, MODULE, one) == 1, "single CHECK");
    check($coverage_get_max(ASSERTION, MODULE, one) == 1, "single GET_MAX");
    check($coverage_get(ASSERTION, MODULE, one) == 1, "single GET");
    check($coverage_get(ASSERTION, HIER, $root) == 1, "partial root numerator");
    one.hit(1);
    one.hit(0);
    check($coverage_control(START, ASSERTION, MODULE, one) == 1, "repeated START");
    check($coverage_get(ASSERTION, MODULE, one) == 1, "sticky per-source hit");
    check($coverage_control(STOP, ASSERTION, MODULE, one) == 1, "STOP");
    check($coverage_control(CHECK, ASSERTION, MODULE, one) == 1, "CHECK after STOP");
    check($coverage_get(ASSERTION, MODULE, one) == 1, "STOP preserved hit");
    check($coverage_get_max(ASSERTION, MODULE, one) == 1, "STOP preserved maximum");
    check($coverage_control(RESET, ASSERTION, MODULE, one) == 1, "RESET");
    one.hit(1);
    check($coverage_get(ASSERTION, MODULE, one) == 0, "RESET preserved STOP");
    check($coverage_get_max(ASSERTION, MODULE, one) == 1, "RESET preserved maximum");

    tick();
    check($coverage_get(ASSERTION, MODULE, delay_checker) == 0, "attempt still in flight");
    check($coverage_get(ASSERTION, MODULE, vac) == 0, "disabled evaluation");
    check($coverage_control(STOP, ASSERTION, MODULE, delay_checker) == 1, "stop in flight");
    vac_disabled = 0;
    tick();
    check(actions == 1, "stopped collection allowed pass action");
    check($coverage_get(ASSERTION, MODULE, delay_checker) == 0, "stopped attempt did not hit");
    check($coverage_get(ASSERTION, MODULE, vac) == 3, "vacuous-only assume and cover hits");
    check($coverage_control(START, ASSERTION, MODULE, delay_checker) == 1, "restart collection");
    outcome = 0;
    tick();
    check(failures == 1, "delayed failure action");
    check($coverage_get(ASSERTION, MODULE, delay_checker) == 0, "failure did not hit");
    $assertpassoff(0, delay_checker.p);
    outcome = 1;
    tick();
    tick();
    check(actions == 1, "pass actions disabled");
    check($coverage_get(ASSERTION, MODULE, delay_checker) == 1, "pass actions independent of hits");
    check($coverage_get_max(ASSERTION, MODULE, delay_checker) == 1, "post-clock maximum");

    check($coverage_control(RESET, ASSERTION, MODULE, delay_checker) == 1, "reset live checker");
    inspect = 1;
    tick();
    inspect = 0;
    check(observations == 1, "Reactive observer ran");
    check($coverage_get(ASSERTION, MODULE, delay_checker) == 0, "dispatch did not recreate reset hit");
    $assertkill(0, delay_checker.p);
    $asserton(0, delay_checker.p);
    tick();
    check($coverage_get(ASSERTION, MODULE, delay_checker) == 0, "killed attempt did not hit");
    disabled = 1; // Cancel the in-flight attempt before the next clock.
    tick();
    check($coverage_get(ASSERTION, MODULE, delay_checker) == 0, "canceled attempt did not hit");

    proc_clk = 1;
    #1;
    check($coverage_get_max(ASSERTION, MODULE, proc) == 2,
          "procedural inventory excludes expect/restrict/endpoint helper");
    check($coverage_get(ASSERTION, MODULE, proc) == 2, "procedural assert and declarative cover hits");
    check($coverage_get_max(ASSERTION, MODULE, deferred_checks) == 4, "deferred inventory");
    check($coverage_get(ASSERTION, MODULE, deferred_checks) == 2, "only matured deferred hits");

    check($coverage_get_max(ASSERTION, MODULE, left) == 2, "instance MODULE maximum");
    check($coverage_get_max(ASSERTION, HIER, left) == 5, "instance HIER maximum");
    check($coverage_get(ASSERTION, MODULE, left) == 2, "lexical/generate assertions belong to instance");
    check($coverage_get(ASSERTION, MODULE, left.g[0].child) == 1, "generated child instance handle");
    check($coverage_get(ASSERTION, MODULE, "coverage_family") == 4, "all copies MODULE");
    check($coverage_get(ASSERTION, HIER, "coverage_family") == 10, "all copies HIER");
    check($coverage_get(ASSERTION, MODULE, "coverage_leaf") == 4, "definition under generate scopes");
    check($coverage_get(ASSERTION, HIER, "coverage_tree") == 2, "overlapping HIER selection");
    check($coverage_get(ASSERTION, MODULE, definition) == 2, "qualified nested definition");
    check($coverage_get(ASSERTION, MODULE, "coverage_other.slot") == 2, "same-leaf nested definition");
    check($coverage_control(RESET, ASSERTION, MODULE, definition) == 1, "reset qualified definition");
    check($coverage_get(ASSERTION, MODULE, definition) == 0, "reset every selected nested instance");
    check($coverage_get_max(ASSERTION, MODULE, definition) == 2, "reset nested maximum");
    check($coverage_get(ASSERTION, HIER, other) == 2, "different nested definition survived reset");
    check($coverage_control(RESET, ASSERTION, MODULE, left) == 1, "reset only one instance");
    check($coverage_get(ASSERTION, HIER, left) == 2, "MODULE reset spared child modules");
    check($coverage_get(ASSERTION, HIER, right) == 4, "MODULE reset spared other copy");
    check($coverage_control(RESET, ASSERTION, HIER, right) == 1, "reset one instance tree");
    check($coverage_get(ASSERTION, HIER, right) == 0, "HIER reset included children");
    check($coverage_get(ASSERTION, HIER, left) == 2, "HIER reset spared other tree");

    check($coverage_control(CHECK, ASSERTION, MODULE, empty) == 0, "valid empty CHECK");
    check($coverage_control(START, ASSERTION, HIER, "coverage_empty") == 0, "valid empty START");
    check($coverage_control(STOP, ASSERTION, MODULE, empty) == 1, "valid empty STOP");
    check($coverage_control(RESET, ASSERTION, HIER, empty) == 1, "valid empty RESET");
    check($coverage_get_max(ASSERTION, HIER, empty) == 0, "valid empty maximum");
    check($coverage_get(ASSERTION, HIER, empty) == 0, "valid empty numerator");

    check($coverage_control(RESET, ASSERTION, HIER, "coverage_family.inst") == -1, "instance name string is invalid");
    check($coverage_get_max(ASSERTION, HIER, "slot") == -1, "unqualified nested definition is invalid");
    check($coverage_get(ASSERTION, MODULE, "") == -1, "empty definition string is invalid");
    check($coverage_control(RESET, ASSERTION, 12, left) == -1, "invalid scope constant");
    check($coverage_get(ASSERTION, HIER, left) == 2, "invalid controls left state intact");
    check($coverage_get_max(ASSERTION, HIER, $root) == 28, "root denominator stayed constant");

    temporal_tick();
    check($coverage_get(ASSERTION, MODULE, finite) == 0, "always window still pending");
    check($coverage_get(ASSERTION, MODULE, eventual) == 1, "eventually succeeds at first match");
    check($coverage_get(ASSERTION, MODULE, accepted) == 1, "abort-to-pass contributes a hit");
    $assertoff(0, finite);
    $assertoff(0, eventual);
    check($coverage_control(RESET, ASSERTION, MODULE, eventual) == 1, "reset completed eventual");
    temporal_tick();
    check($coverage_get(ASSERTION, MODULE, finite) == 0, "always has not met its final sample");
    temporal_tick();
    check($coverage_get(ASSERTION, MODULE, finite) == 1, "always completes its whole window");
    check($coverage_get(ASSERTION, MODULE, eventual) == 0, "completed attempt cannot hit again");
    $display("PASSED");
    $finish(0);
  end
endmodule
