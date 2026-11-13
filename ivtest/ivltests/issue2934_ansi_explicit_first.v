module child(input .b(w), output .y(z));
  logic w;
  logic z;
  assign z = w;
endmodule

module top;
  logic a;
  wire y;
  child dut(.b(a), .y(y));
  initial begin
    a = 1'b0;
    #1;
    if (y !== 1'b0) $fatal(1, "input explicit port did not propagate 0");
    a = 1'b1;
    #1;
    if (y !== 1'b1) $fatal(1, "input explicit port did not propagate 1");
    $display("PASSED");
  end
endmodule
