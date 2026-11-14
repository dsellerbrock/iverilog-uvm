module child(input logic a, output logic b);
  assign b = a;
endmodule

module top;
  logic a = 1;
  wire b;
  child c(a, b);
  initial begin
    $inspect_iterator;
    $finish;
  end
endmodule
