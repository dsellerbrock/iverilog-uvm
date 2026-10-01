`timescale 1ns/1ps
module sv_ref_event_relay_auto;
  int seen[2];

  task automatic edge_once(const ref logic signal_value, input int tag);
    @(posedge signal_value);
    seen[tag]++;
  endtask

  task automatic caller(input int tag, input int delay_ns);
    logic local_signal = 0;
    fork edge_once(local_signal, tag); join_none
    #(delay_ns) local_signal = 1;
    #1;
  endtask

  initial begin
    fork
      caller(0, 1);
      caller(1, 3);
    join_none
    #2 if (seen[0] != 1 || seen[1] != 0)
      $fatal(1, "automatic ref calls cross-woke or missed first edge");
    #2 if (seen[0] != 1 || seen[1] != 1)
      $fatal(1, "automatic ref calls missed second edge");
    $display("PASSED automatic ref event relay");
  end
endmodule
