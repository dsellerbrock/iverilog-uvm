// Regression: a covergroup declared at module/interface scope (not inside a
// class) must register its NAME as a usable type, so the common pattern of
// instantiating it and calling sample() compiles:
//   covergroup my_cg @(posedge clk); ... endgroup
//   covergroup samp_cg with function sample(bit [2:0] v); ... endgroup
//   my_cg   c1 = new();   c1.sample();
//   samp_cg c2 = new();   c2.sample(3'b101);
// (OpenTitan i2c_protocol_cov.sv and other SVA checker modules.) Previously the
// module-item covergroup rule discarded the declaration entirely, so the name
// "doesn't name a type". It is now registered as a STUB type
// (pform_covergroup_stub_typedef): functional coverage is not implemented, so
// new()/sample()/etc. are no-ops, but everything compiles and runs.
module top;
  logic clk = 0;
  bit [2:0] x;
  covergroup my_cg @(posedge clk);
    cp_x: coverpoint x;
  endgroup
  covergroup samp_cg with function sample(bit [2:0] v);
    cp_v: coverpoint v;
  endgroup
  initial begin
    static my_cg   c1 = new();
    static samp_cg c2 = new();
    #1;
    c1.sample();          // no-arg sample (stub no-op)
    c2.sample(3'b101);    // with-function sample (stub no-op)
    $display("PASS");
  end
endmodule
