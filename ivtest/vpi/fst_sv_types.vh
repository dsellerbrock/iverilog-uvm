// Check the FST dumper's SystemVerilog types (IEEE 1800-2023 21.7, 21.7.5):
// the 2-state integer types and strings keep their own FST types, a
// multidimensional packed variable is one vector with its total range, and
// interface instances and generate blocks are dumped as scopes.
interface fst_bus(input logic clk);
  logic [7:0] data;
  logic valid;
  modport mp(input data, valid);
endinterface

module fst_user(fst_bus.mp b);
  wire seen = b.valid;
endmodule

module top;
  logic clk = 0;
  bit b; byte by; shortint si; int i; longint li; integer ig;
  real r; string str;
  logic [3:0][7:0] pmda;
  logic [7:0] mem [0:3]; // unpacked arrays are not dumped (21.7.5)
  fst_bus bus(clk);
  fst_user u(bus);
  for (genvar g = 0; g < 2; g++) begin : gen
    logic [1:0] gv = g;
  end
  initial begin
    $fst_text("fst_sv_types.fst");
    $dumpfile("fst_sv_types.fst");
    $dumpvars(0, top);
    b = 0; by = -1; si = 300; i = -5; li = 64'h1234_5678_9abc_def0; ig = 7;
    r = 1.5; str = "hi"; pmda = 32'hdeadbeef; mem[1] = 8'h11;
    bus.data = 8'haa; bus.valid = 0;
    #5 b = 1; by = 3; si = -2; i = 9; li = 1; ig = 'x;
    r = -3.0; str = "hello"; pmda[2] = 8'h00; bus.valid = 1; mem[1] = 8'h22;
    #5 str = ""; clk = 1;
    #5 $finish(0);
  end
endmodule
