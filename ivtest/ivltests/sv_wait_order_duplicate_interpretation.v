// IEEE 1800-2017/2023 §15.5.4 does not define duplicate event identifiers.
// Keep this regression as an explicit Icarus interpretation, not conformance.
module sv_wait_order_duplicate_interpretation;
  event same;

  initial begin
    fork
      begin
        #1;
        -> same;
        -> same;
      end
      begin
        wait_order(same, same)
          $display("duplicate-event-interpretation-pass");
        else $fatal(1, "duplicate event sequence failed");
      end
    join

    -> same;
    wait_order(same, same)
      $fatal(1, "later duplicate used persistent triggered state");
    else $display("duplicate-persistent-interpretation-pass");
  end
endmodule
