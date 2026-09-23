// RED reducer for the released OpenTitan SPI Device scope-randomized byte queue.
// IEEE 1800-2017/2023 scope: std::randomize on one 1D byte queue with size constraint.
module reducer;
  bit [7:0] byte_q[$];
  bit ok;
  int errors = 0;

  initial begin
    // Positive: the SPI Device operation resizes the queue to the requested
    // byte count. An empty queue also exercises successful growth.
    ok = std::randomize(byte_q) with { byte_q.size() == 3; };
    if (!ok || byte_q.size() != 3) begin
      $display("FAIL: SAT size 3, ok=%0b size=%0d", ok, byte_q.size());
      errors++;
    end

    // Positive boundary: zero is a legal requested size.
    ok = std::randomize(byte_q) with { byte_q.size() == 0; };
    if (!ok || byte_q.size() != 0) begin
      $display("FAIL: SAT size 0, ok=%0b size=%0d", ok, byte_q.size());
      errors++;
    end

    // Negative/transaction boundary: contradictory size constraints must
    // return failure and leave both membership and values intact.
    byte_q = '{8'h12, 8'h34};
    ok = std::randomize(byte_q) with {
      byte_q.size() == 1;
      byte_q.size() == 2;
    };
    if (ok || byte_q.size() != 2 || byte_q[0] != 8'h12 || byte_q[1] != 8'h34) begin
      $display("FAIL: UNSAT must preserve queue; ok=%0b size=%0d", ok, byte_q.size());
      errors++;
    end

    if (errors == 0) $display("PASS");
    else $display("FAILED (%0d)", errors);
    $finish;
  end
endmodule
