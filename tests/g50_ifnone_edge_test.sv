// G50: ifnone with edge-sensitive specify path — now parses correctly.
module top(input a, output b);
  specify
    ifnone (negedge a => b) = 10;
  endspecify
  assign b = a;
  initial begin
    $display("PROBE_OK_ifnone_edge");
    $finish;
  end
endmodule
