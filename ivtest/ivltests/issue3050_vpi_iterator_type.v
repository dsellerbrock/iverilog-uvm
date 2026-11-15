// IEEE 1800-2023 37.84: an iterator reports the type of object it scans as
// its vpiIteratorType.
module child(input logic a, output logic b);
  assign b = a;
endmodule

module top;
  logic a = 1;
  wire b;
  logic [3:0] mem [0:1];
  child c(a, b);
  initial begin
    $probe_iterator_type(a, b);
    $finish;
  end
endmodule
