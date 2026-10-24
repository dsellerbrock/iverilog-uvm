`timescale 1ns/1ns
module p36b;
  reg [7:0] r;
  reg [7:0] mem [0:3];
  wire [7:0] w8 = 8'hA5;

  initial begin
    r = 2;
    mem[0] = 0;
    mem[1] = 1;
    mem[2] = 2;
    mem[3] = 3;
    $probe36b;
    #6 $display("AT6 %0d", r);
    #5 begin
      $report36b;
      $display("AFTER_FINISH");
    end
  end
endmodule
