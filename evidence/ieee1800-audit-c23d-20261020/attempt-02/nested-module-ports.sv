module outer(input logic a, output logic b);
  module inner(input logic i, output logic o);
    assign o = i;
  endmodule
  inner u(.i(a), .o(b));
endmodule

module top;
  logic result;
  outer u(.a(1'b1), .b(result));
  initial begin
    #1;
    if (result !== 1'b1) $fatal(1, "nested module port connection failed");
    $display("PASS: nested module ports");
  end
endmodule
