// G52: declarative net delays (wire #5 a;) — delay parsed but ignored.
module top;
  wire #5 a;
  logic b;
  assign a = b;
  initial begin
    b = 1;
    $display("PROBE_OK_net_delay");
    $finish;
  end
endmodule
