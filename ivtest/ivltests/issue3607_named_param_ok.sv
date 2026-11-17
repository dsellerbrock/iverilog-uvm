module leaf #(parameter int N = 1) (output integer value);
  assign value = N;
endmodule
module top;
  localparam int N = 3;
  wire [31:0] assigned, defaulted;
  leaf #(.N(N)) a (assigned);
  leaf #(.N()) b (defaulted);
  initial begin
    #1;
    if (assigned !== 3 || defaulted !== 1) $fatal(1, "wrong parameter values");
    $display("PASS");
  end
endmodule
