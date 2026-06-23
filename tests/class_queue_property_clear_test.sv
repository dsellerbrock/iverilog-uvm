// Clearing a class-property queue with `q = {}` must leave an EMPTY QUEUE, not
// null, so a subsequent push_back works.
//
// iverilog elaborates an empty queue assignment-pattern (`{}`) as a null
// expression; the property store then wrote %null into the queue property, so
// q.push_back(...) afterwards operated on null and was silently dropped (size
// stayed 0).  This is the OpenTitan aon_timer_scoreboard reset() pattern
// (`predicted_wdog_intr_q = {}; predicted_wdog_intr_q.push_back(0);`), which
// left the queue empty and later tripped a `Queue is empty` uvm_fatal.
//
// Fixed by building an empty queue object for `q = {}` on a queue property.
class C;
  bit    bq[$];
  int    iq[$];
  string sq[$];
  function void clear_and_push();
    bq = {}; bq.push_back(1'b1);          // exact OT idiom
    iq = {}; iq.push_back(42);
    sq = {}; sq.push_back("x");
  endfunction
endclass

module top;
  initial begin
    C c = new();
    bit ok = 1'b1;

    // pre-populate, then clear+push (mirrors a reset after activity)
    c.bq.push_back(0); c.bq.push_back(0);
    c.iq.push_back(7);
    c.clear_and_push();

    if (c.bq.size() != 1 || c.bq[0] !== 1'b1) begin ok=0; $display("FAIL bit q size=%0d", c.bq.size()); end
    if (c.iq.size() != 1 || c.iq[0] != 42)    begin ok=0; $display("FAIL int q size=%0d", c.iq.size()); end
    if (c.sq.size() != 1 || c.sq[0] != "x")   begin ok=0; $display("FAIL str q size=%0d", c.sq.size()); end

    // clear-on-empty (no prior population) must also yield a usable queue
    begin
      C c2 = new();
      c2.bq = {}; c2.bq.push_back(1'b1);
      if (c2.bq.size() != 1) begin ok=0; $display("FAIL clear-on-empty size=%0d", c2.bq.size()); end
    end

    if (ok) $display("QUEUE_PROP_CLEAR_PASS");
    else    $display("QUEUE_PROP_CLEAR_FAIL");
    $finish;
  end
endmodule
