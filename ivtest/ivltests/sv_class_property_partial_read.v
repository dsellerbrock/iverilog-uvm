// Read-path audit P0 fix: r-value bit/part/indexed-part selects of packed
// vector CLASS PROPERTIES (IEEE 1800-2017 11.5.1, 8.3). Formerly: 4-state
// selects crashed vvp (property_logic::get_vec4 assert idx < array_size_ —
// the select base was mis-encoded as a property ARRAY index, %prop/v/i),
// 2-state selects silently returned zeros, multi-dim selects used only the
// first index, and chained-handle selects (o.inr.v[3:0]) silently dropped
// the select. Covers: constant/variable bit, [m:l], [b +: w], [b -: w],
// 2-state int, multi-dim element/bit/part, virtual-interface flat member,
// chained handles, this.-selects in methods, expression contexts.
interface pr_if; logic [15:0] flat; endinterface

module sv_class_property_partial_read;
  class R; logic [7:0] v; int w; logic [3:0][7:0] m; endclass
  class Inner; logic [7:0] v; endclass
  class Outer; Inner inr; function new(); inr = new; endfunction endclass
  class M;
    logic [7:0] v;
    function logic [3:0] lo(); return this.v[3:0]; endfunction
    function logic [3:0] hi(); return v[7:4]; endfunction
  endclass

  pr_if ifc();
  virtual pr_if vif;
  int errors = 0;
  function automatic int f(logic [3:0] x); return x + 1; endfunction

  initial begin
    automatic R r = new;
    automatic Outer o = new;
    automatic M m = new;
    vif = ifc;

    r.v = 8'hA5;
    if (r.v[3:0] !== 4'h5) begin $display("FAIL lo=%h", r.v[3:0]); errors++; end
    if (r.v[7:4] !== 4'hA) begin $display("FAIL hi=%h", r.v[7:4]); errors++; end
    if (r.v[7] !== 1'b1 || r.v[0] !== 1'b1 || r.v[1] !== 1'b0) begin $display("FAIL bits"); errors++; end
    for (int i = 0; i < 8; i++)
      if (r.v[i] !== ((8'hA5 >> i) & 1'b1)) begin $display("FAIL var bit i=%0d", i); errors++; end
    for (int i = 0; i < 2; i++)
      if (r.v[i*4 +: 4] !== ((i == 0) ? 4'h5 : 4'hA)) begin $display("FAIL +: i=%0d", i); errors++; end
    if (r.v[7 -: 4] !== 4'hA) begin $display("FAIL -:"); errors++; end

    r.w = 32'h12345678;
    if (r.w[15:8] !== 8'h56) begin $display("FAIL int part=%h", r.w[15:8]); errors++; end
    if (r.w[31:28] !== 4'h1) begin $display("FAIL int hi"); errors++; end

    r.m = 32'h0403_0201;
    if (r.m[1] !== 8'h02) begin $display("FAIL md elem=%h", r.m[1]); errors++; end
    if (r.m[0][5] !== 1'b0 || r.m[3][2] !== 1'b1) begin $display("FAIL md bit"); errors++; end
    if (r.m[2][3:0] !== 4'h3) begin $display("FAIL md part=%h", r.m[2][3:0]); errors++; end

    vif.flat = 16'hBEEF;
    if (vif.flat[7:0] !== 8'hEF) begin $display("FAIL vif lo=%h", vif.flat[7:0]); errors++; end
    if (vif.flat[15:12] !== 4'hB) begin $display("FAIL vif hi"); errors++; end

    o.inr.v = 8'hC3;
    if (o.inr.v[3:0] !== 4'h3) begin $display("FAIL chain lo=%h", o.inr.v[3:0]); errors++; end
    if (o.inr.v[7:4] !== 4'hC) begin $display("FAIL chain hi"); errors++; end

    m.v = 8'h5A;
    if (m.lo() !== 4'hA) begin $display("FAIL this lo"); errors++; end
    if (m.hi() !== 4'h5) begin $display("FAIL method hi"); errors++; end

    begin
      automatic R r2 = new; r2.v = 8'h96;
      if ({r2.v[3:0], r2.v[7:4]} !== 8'h69) begin $display("FAIL concat"); errors++; end
      if (f(r2.v[3:0]) !== 7) begin $display("FAIL fnarg"); errors++; end
      if (!(r2.v[7:4] == 4'h9)) begin $display("FAIL ifcond"); errors++; end
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
