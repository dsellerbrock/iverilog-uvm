// SystemVerilog checkers (IEEE 1800-2017 clause 17), the module-like
// subset: typed formals (directionless formals default to INPUT per
// 17.4), default formal values, sequence/property declarations,
// concurrent assert/cover, default clocking, internal variables and
// procedures, multiple instances with independent assertion state,
// and the endchecker label. Was a whole-declaration loud sorry.
checker rise_stable(input logic clk, logic sig);
  int fails = 0;
  property p_stable;
    @(posedge clk) $rose(sig) |=> sig;
  endproperty
  a_st: assert property (p_stable) else fails++;
  c_rose: cover property (@(posedge clk) $rose(sig));
endchecker : rise_stable

checker dflt_en(input logic clk, logic en = 1'b1);
  int fails = 0;
  default clocking @(posedge clk); endclocking
  a_en: assert property (en) else fails++;
endchecker

module main;
  bit failed = 0;
  task check(string label, bit ok);
    if (!ok) begin
       $display("FAILED -- %0s", label);
       failed = 1;
    end
  endtask

  logic clk = 0;
  logic good = 0, bad = 0, off = 0;
  always #5 clk = ~clk;

  rise_stable chk_good(clk, good);
  rise_stable chk_bad(.clk(clk), .sig(bad));

  dflt_en c1(clk);        // omitted en uses the 1'b1 default
  dflt_en c2(clk, off);   // en=0: violates on every posedge

  initial begin
    @(negedge clk) begin good = 1; bad = 1; end
    @(negedge clk) begin good = 1; bad = 0; end  // bad breaks |=> sig
    @(negedge clk) begin good = 0; bad = 0; end
    #22;  // through the posedge at t=45

    // independent per-instance assertion state
    check("good instance clean", main.chk_good.fails == 0);
    check("bad instance failed once", main.chk_bad.fails == 1);

    // default formal value vs explicit actual
    check("default en clean", main.c1.fails == 0);
    check("en=0 violates every posedge", main.c2.fails >= 4);

    if (!failed) $display("PASSED");
    $finish(0);
  end
endmodule
