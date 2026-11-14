module top;
  parameter int P = 3;
  initial begin
    #1 $probe;
    $display("DONE");
  end
endmodule
