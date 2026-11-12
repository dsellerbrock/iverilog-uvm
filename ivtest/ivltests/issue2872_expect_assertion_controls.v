module issue2872_expect_assertion_controls;
  logic clk = 0, a = 0;
  always #5 clk = ~clk;
  initial begin
    $assertoff;
    expect (@(posedge clk) a) $display("%0t e1 pass", $time); else $display("%0t e1 fail", $time);
    $asserton;
    $assertfailoff;
    expect (@(posedge clk) a) $display("%0t e2 pass", $time); else $display("%0t e2 fail", $time);
    $assertfailon;
    $assertcontrol(9, 16);
    expect (@(posedge clk) a) $display("%0t e3 pass", $time); else $display("%0t e3 fail", $time);
    $assertcontrol(8, 16);
    expect (@(posedge clk) a) $display("%0t e4 pass", $time); else $display("%0t e4 fail", $time);
    a = 1;
    $assertpassoff;
    expect (@(posedge clk) a) $display("%0t e5 pass", $time); else $display("%0t e5 fail", $time);
    $assertpasson;
    expect (@(posedge clk) a) $display("%0t e6 pass", $time); else $display("%0t e6 fail", $time);
    $finish;
  end
endmodule
