module child;
endmodule

module top;
  logic a;
  child u();
  initial begin
    a = 0; #1 a = 1; #1 $probe;
    $display("DONE");
  end
endmodule
