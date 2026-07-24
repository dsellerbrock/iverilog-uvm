module top;
  reg [7:0] a = 0, b = 0;
  initial begin
    $arm_cbs;
    a = 1;
    b <= 2;          // NBA: settles between cbReadWriteSynch and cbReadOnlySynch
    $display("[%0t] active: a=%0d b=%0d", $time, a, b);
    #1 $display("[%0t] next: a=%0d b=%0d", $time, a, b);
    $finish(0);
  end
endmodule
