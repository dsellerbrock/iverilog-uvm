// Race test: set m_wait_id BEFORE the wait starts (item_done fires before wait_for_item_done reaches %wait)
// This tests whether iverilog handles the case where the condition becomes true
// before %wait executes.

class Sequencer;
  int m_wait_id = -1;
endclass

module top;
  Sequencer sqr;

  initial begin
    sqr = new();

    // Producer fires IMMEDIATELY (zero time) before consumer reaches wait
    fork
      begin
        // At time 0, set done before consumer reaches wait
        sqr.m_wait_id = 1;
      end
      begin
        // Consumer: reset then wait - but producer already set it to 1!
        sqr.m_wait_id = -1;  // reset (this fires AFTER producer at time 0)
        wait (sqr.m_wait_id == 1);
        $display("PASS: wait completed (may have found it already true)");
        $finish;
      end
    join_none

    #100;
    $display("FAIL: timeout - wait blocked forever");
    $finish(1);
  end
endmodule
