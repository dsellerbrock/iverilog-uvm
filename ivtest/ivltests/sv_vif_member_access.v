// Virtual-interface member read/write at correct widths (IEEE 1800-2017 25.9).
// A member write through a virtual interface handle must reach the full width
// of the interface member. Pins the cases that work correctly today:
//   - a non-parameterized interface,
//   - a parameterized interface used at its DEFAULT parameter.
// (Parameterized virtual-interface SPECIALIZATION with a NON-default override
// is a recorded limitation: all specializations share one netclass elaborated
// with the interface defaults, so a non-default member write would truncate.
// That case is diagnosed with a loud one-time warning at elaboration; see
// docs/conformance/repros/param_vif_member_write_truncation.sv.)
module sv_vif_member_access;
  int errors = 0;

  initial begin
    // Non-parameterized interface: full 16-bit member write via vif.
    top.run_nonparam();
    // Parameterized interface at default width (8): vif write is full width.
    top.run_default();
    if (top.errs == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", top.errs);
  end
endmodule

interface wide_if(input bit clk);
  logic [15:0] data;
endinterface

interface pdef_if #(parameter W = 8)(input bit clk);
  logic [W-1:0] data;
endinterface

module top;
  bit clk = 0;
  wide_if  w (clk);
  pdef_if  p (clk);     // default W = 8
  int errs = 0;

  task run_nonparam();
    virtual wide_if v = w;
    v.data = 16'hBEEF;
    #1;
    if (w.data !== 16'hBEEF) begin
      $display("FAIL nonparam w.data=%0h (expect beef)", w.data); errs++; end
    // read back through the vif
    w.data = 16'h1234;
    #1;
    if (v.data !== 16'h1234) begin
      $display("FAIL nonparam-read v.data=%0h (expect 1234)", v.data); errs++; end
  endtask

  task run_default();
    virtual pdef_if v = p;
    v.data = 8'hA5;
    #1;
    if (p.data !== 8'hA5) begin
      $display("FAIL default p.data=%0h (expect a5)", p.data); errs++; end
  endtask
endmodule
