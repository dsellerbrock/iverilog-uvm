// G51: ->> non-blocking event trigger — parsed, statement skipped (not supported).
module top;
  event e;
  initial begin
    ->> e;
    $display("PROBE_OK_nb_trigger_warn");
    $finish;
  end
endmodule
