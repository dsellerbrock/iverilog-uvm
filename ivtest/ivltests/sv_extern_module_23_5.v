extern module ext_nonansi_23_5 (a, b);
extern module ext_param_23_5 #(parameter WIDTH = 2)
    (input [WIDTH-1:0] data_in, output [WIDTH-1:0] data_out);

module top;
  logic a;
  wire b;
  logic [4:0] data_in;
  wire [4:0] data_out;

  assign a = 1'b1;
  assign data_in = 5'b10101;
  ext_nonansi_23_5 u_nonansi (.*);
  ext_param_23_5 #(.WIDTH(5)) u_param (.*);

  initial begin
    #1;
    if (b !== a) $fatal(1, "non-ANSI extern port mismatch");
    if (data_out !== data_in) $fatal(1, "parameterized ANSI extern port mismatch");
    $display("extern module ports passed");
    $finish;
  end
endmodule

module ext_nonansi_23_5 (.*);
  input a;
  output b;
  assign b = a;
endmodule

module ext_param_23_5 (.*);
  assign data_out = data_in;
endmodule
