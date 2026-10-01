// A hierarchical reference is not allowed in a constant expression (IEEE
// 1800-2017/2023 11.2.1). Commercial tools accept an instance-path parameter
// there (OpenTitan csrng tb uses tb.dut.u_core.u_gen.BlkLen as a part-select
// width), so Icarus accepts it only under -gcommercial-unsafe;
// sv_hier_param_constant_fail keeps strict mode.
module gen #(parameter int BlkLen = 128, parameter int FifoWidth = 256) ();
endmodule
module core (); gen #(.BlkLen(64), .FifoWidth(96)) u_gen (); endmodule
module test;
  core u_core ();
  logic [95:0] data = 96'h1234_5678_9abc_def0_1357_2468;
  logic [63:0] top;
  localparam int W = test.u_core.u_gen.BlkLen;
  initial begin
    top = data[test.u_core.u_gen.FifoWidth-1 -: test.u_core.u_gen.BlkLen];
    if (W == 64 && top == 64'h1234_5678_9abc_def0) $display("PASSED");
    else $display("FAILED %0d %h", W, top);
  end
endmodule
