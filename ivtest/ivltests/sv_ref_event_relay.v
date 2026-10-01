`timescale 1ns/1ps
module sv_ref_event_relay;
  typedef struct packed { logic ready; logic valid; } bus_t;
  logic a = 0, b = 0, high = 1;
  bus_t bus = '0;
  int seen[8];

  task automatic edge_once(const ref logic signal_value, input int tag);
    @(posedge signal_value);
    seen[tag]++;
  endtask

  task automatic ready_once(const ref bus_t value);
    wait (value.ready);
    seen[6]++;
  endtask

  task automatic detached(const ref logic signal_value);
    fork edge_once(signal_value, 7); join_none
  endtask

  initial begin
    fork
      edge_once(a, 0);
      edge_once(b, 1);
      edge_once(a, 2);
      ready_once(bus);
    join_none
    #1 a = 1; bus.ready = 1;
    #1 if (seen[0] != 1 || seen[1] != 0 || seen[2] != 1 || seen[6] != 1)
      $fatal(1, "concurrent ref waits cross-woke or missed");
    b = 1;
    #1 if (seen[1] != 1) $fatal(1, "second source did not wake");

    a = 0; b = 0;
    fork edge_once(b, 3); join_none
    #1 a = 1;
    #1 if (seen[3] != 0) $fatal(1, "reused frame heard old source");
    b = 1;
    #1 if (seen[3] != 1) $fatal(1, "reused frame missed new source");

    a = 0;
    fork edge_once(a, 4); join_none
    #1 disable fork;
    a = 1;
    #1 if (seen[4] != 0) $fatal(1, "disabled waiter resumed");

    fork edge_once(high, 5); join_none
    #1 high = 0;
    #1 if (seen[5] != 0) $fatal(1, "initial high made false posedge");
    high = 1;
    #1 if (seen[5] != 1) $fatal(1, "real posedge missed after seed");

    b = 0;
    detached(b);
    #1 b = 1;
    #1 if (seen[7] != 1) $fatal(1, "detached ref chain missed edge");
    $display("PASSED ref event relay");
  end
endmodule
