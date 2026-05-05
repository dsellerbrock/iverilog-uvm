// Minimal test: wait(class_member == value) where another thread modifies the member
// This tests whether iverilog correctly wakes the wait when a class property changes.

class Sequencer;
  int m_wait_id = -1;
  int m_arb_size = 0;
endclass

module top;
  Sequencer sqr;
  int done_count = 0;

  initial begin
    sqr = new();

    // Producer: sets m_wait_id after 5 time units, 6 times
    fork
      begin
        repeat (6) begin
          #5;
          sqr.m_arb_size++;  // spurious mutation
          #5;
          sqr.m_wait_id = done_count + 1;  // set the "done" signal
          done_count++;
        end
      end
    join_none

    // Consumer: wait for each of 6 completions
    begin
      int expected;
      for (int i = 1; i <= 6; i++) begin
        expected = i;
        sqr.m_wait_id = -1;  // reset
        wait (sqr.m_wait_id == expected);
        $display("Item %0d done at time %0t", i, $time);
      end
      $display("PASS: all 6 items processed");
      $finish;
    end
  end

  // Timeout
  initial begin
    #200;
    $display("FAIL: timeout");
    $finish(1);
  end
endmodule
