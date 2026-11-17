module leaf #(parameter int N = 1) (output integer value);
  assign value = N;
endmodule
module top;
  localparam int N = 3;
  wire [31:0] value;
  leaf #(.N) inst (value);
  initial begin
    #1;
    if (value !== 3) $fatal(1, "wrong parameter value");
    $display("PASS");
  end
endmodule
