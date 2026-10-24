module dut;
  reg clk = 0;
  reg v = 0;
  always #5 clk = ~clk;

  task T;
    @(posedge clk);
    v <= 1'b1;
  endtask

  always @(v)
    if (v) $display("DESIGN %0t %0b", $time, v);
endmodule

program test;
  initial begin
    dut.T();
    $display("RETURN %0t %0b", $time, dut.v);
    @(posedge dut.clk);
    $display("NEXT %0t %0b", $time, dut.v);
    $finish;
  end
endprogram
