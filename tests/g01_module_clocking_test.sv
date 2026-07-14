// G01/G02 regression: clocking blocks outside interfaces.
// IEEE 1800-2017 14.3: a clocking block may be declared in a module,
// interface, program, or checker. Previously `clocking` in a module or
// program emitted "only allowed in interfaces" and then died on the
// pform.cc is_interface assertion (hard crash). 14.12: default clocking
// declarations (named, anonymous, and the reference form) were parsed
// and silently dropped; they are now registered like any other clocking
// block. 14.4: skew syntax (#1step, #0, #(n), edge [#d], default
// input/output skews) parses; skew *semantics* remain the alias model
// (cb.sig accesses the underlying signal directly).
//
// Checks:
//   1. module-scope clocking: @(cb) waits for the clocking event
//   2. module-scope clocking: cb.in reads the underlying signal
//   3. module-scope clocking: cb.out <= drives the underlying signal
//   4. named default clocking is registered and usable by name
//   5. `default clocking cb;` reference form accepted
//   6. hierarchical @(sub.cb) and sub.cb.sig from the parent module
//   7. program-block clocking: input read + output drive (G02)
//   8. skew syntax parses on every A.6.11 clocking_item form
//   9. multiple clocking blocks in one module coexist

`timescale 1ns/1ns

// -- 6: submodule with its own clocking block ------------------------
module g01_sub(input logic clk);
  logic [7:0] q;
  clocking sub_cb @(posedge clk);
    input q;
  endclocking
endmodule

// -- 7: program block with a clocking block (G02) --------------------
program g01_prog(input logic clk, input logic [7:0] pin, output logic [7:0] pout);
  clocking pcb @(posedge clk);
    input pin;
    output pout;
  endclocking
  initial begin
    @(pcb);
    if (pcb.pin !== 8'h5a) $display("FAIL: program pcb.pin = %h", pcb.pin);
    pcb.pout <= 8'h77;
    @(pcb);
    if (pout !== 8'h77) $display("FAIL: program pcb.pout = %h", pout);
    else $display("PROGRAM CLOCKING OK");
  end
endprogram

module g01_module_clocking_test;
  logic clk = 0;
  logic [7:0] data = 8'h00;
  logic [7:0] result = 8'h00;
  logic [7:0] pin = 8'h5a;
  logic [7:0] pout;
  logic [3:0] dv = 4'h0;
  logic s1 = 0, s2 = 0, s3 = 0, s4 = 0, s5 = 0;
  int errors = 0;

  always #5 clk = ~clk;

  g01_sub  u_sub (.clk(clk));
  g01_prog u_prog(.clk(clk), .pin(pin), .pout(pout));

  // -- 1..3: plain module-scope clocking block -----------------------
  clocking cb @(posedge clk);
    input data;
    output result;
  endclocking

  // -- 8: every clocking_item skew form (A.6.11 / 14.4) --------------
  clocking skew_cb @(posedge clk);
    input #1step s1;
    output #0 s2;
    input #2 s3;
    input posedge #1step s4;
    default input #1step output #0;
    input #1step output #0 s5;
  endclocking

  // -- 4: named default clocking (also checks 9: coexistence) --------
  default clocking dcb @(posedge clk);
    input dv;
  endclocking

  task automatic check(string name, logic [7:0] got, logic [7:0] want);
    if (got !== want) begin
      $display("FAIL: %s = %h (want %h)", name, got, want);
      errors++;
    end
  endtask

  initial begin
    data = 8'h42;
    dv = 4'h9;
    s1 = 1;

    // 1+2: @(cb) waits for posedge clk; cb.data reads `data`
    @(cb);
    check("cb.data", cb.data, 8'h42);

    // 3: synchronous drive through the clocking block
    cb.result <= 8'h99;
    @(cb);
    check("result", result, 8'h99);

    // 4: default clocking block used by name
    @(dcb);
    check("dcb.dv", {4'h0, dcb.dv}, 8'h09);

    // 8: skewed signals still alias the underlying nets
    @(skew_cb);
    check("skew_cb.s1", {7'h0, skew_cb.s1}, 8'h01);
    skew_cb.s2 <= 1;
    @(skew_cb);
    check("s2", {7'h0, s2}, 8'h01);

    // 6: hierarchical clocking access into a submodule
    u_sub.q = 8'hc3;
    @(u_sub.sub_cb);
    check("u_sub.sub_cb.q", u_sub.sub_cb.q, 8'hc3);

    if (errors == 0) $display("PASS: module/program clocking blocks");
    else $display("FAIL: %0d errors", errors);
    $finish(0);
  end
endmodule

// -- 5: reference form in a sibling module ---------------------------
module g01_default_ref_check;
  logic clk2 = 0;
  clocking rcb @(posedge clk2);
  endclocking
  default clocking rcb;
endmodule
