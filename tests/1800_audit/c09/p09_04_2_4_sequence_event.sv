module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  logic clk = 0, a = 0, b = 0, c = 0; time t1, t2;
  sequence abc; @(posedge clk) a ##1 b ##1 c; endsequence
  always #5 clk = ~clk;
  initial begin #1 a = 1; #10 b = 1; #10 c = 1; end
  initial begin @ abc; t1 = $time; end
  initial begin @(abc); t2 = $time; end
  initial begin #30;
    chk("9.4.2.4.at_sequence_instance", t1 == 25);
    chk("9.4.2.4.at_paren_sequence_instance", t2 == 25);
    $display("DONE fails=%0d", fails); $finish;
  end
endmodule
