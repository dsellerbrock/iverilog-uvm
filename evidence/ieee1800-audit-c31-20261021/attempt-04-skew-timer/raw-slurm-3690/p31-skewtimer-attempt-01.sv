`timescale 1ns/1ns

module p31_skewtimer;
  reg a1 = 0, b1 = 0, n1 = 0;
  reg a2 = 0, b2 = 0, n2 = 0;
  reg a3 = 0, b3 = 0, n3 = 0;
  reg a4 = 0, b4 = 0, n4 = 0;
  reg a5 = 0, b5 = 0, n5 = 0;
  integer k1 = 0, k2 = 0, k3 = 0, k4 = 0, c0 = 0;

  specify
    $timeskew(posedge a1, posedge b1, 2, n1);
    $timeskew(posedge a2, posedge b2, 2, n2);
    $timeskew(posedge a3, posedge b3, 2, n3, 1);
    $fullskew(posedge a4, posedge b4, 2, 2, n4);
    $skew(posedge a5, posedge b5, 2, n5);
  endspecify

  always @(n1) if ($time > 0) begin k1++; $display("K1 %0t", $time); end
  always @(n2) if ($time > 0) begin k2++; $display("K2 %0t", $time); end
  always @(n3) if ($time > 0) begin k3++; $display("K3 %0t", $time); end
  always @(n4) if ($time > 0) begin k4++; $display("K4 %0t", $time); end
  always @(n5) if ($time > 0) begin c0++; $display("C0 %0t", $time); end

  initial begin
    #10 a1 = 1;
    a2 = 1;
    a3 = 1;
    a5 = 1;
  end

  initial begin
    #30 b2 = 1;
  end

  initial begin
    #50 a4 = 1;
  end

  initial begin
    #60 $display("COUNTS K1=%0d K2=%0d K3=%0d K4=%0d C0=%0d", k1, k2, k3, k4, c0);
  end
endmodule
