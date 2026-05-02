module top;
   bit pass;
   int q [$];
   int i;

   initial begin
      pass = 1;

      q.push_back(5);
      q.push_back(2);
      q.push_back(8);
      q.push_back(1);
      q.push_back(4);

      q.sort();
      if (q[0] != 1) begin $display("FAIL: sort q[0]=%0d", q[0]); pass = 0; end
      if (q[1] != 2) begin $display("FAIL: sort q[1]=%0d", q[1]); pass = 0; end
      if (q[2] != 4) begin $display("FAIL: sort q[2]=%0d", q[2]); pass = 0; end
      if (q[3] != 5) begin $display("FAIL: sort q[3]=%0d", q[3]); pass = 0; end
      if (q[4] != 8) begin $display("FAIL: sort q[4]=%0d", q[4]); pass = 0; end

      q.rsort();
      if (q[0] != 8) begin $display("FAIL: rsort q[0]=%0d", q[0]); pass = 0; end
      if (q[4] != 1) begin $display("FAIL: rsort q[4]=%0d", q[4]); pass = 0; end

      // Unique: clear and refill with duplicates
      while (q.size() > 0) q.pop_back();
      q.push_back(3);
      q.push_back(1);
      q.push_back(2);
      q.push_back(1);
      q.push_back(3);

      q.unique();
      if (q.size() != 3) begin $display("FAIL: unique size=%0d (expect 3)", q.size()); pass = 0; end

      if (pass) $display("QUEUE SORT TEST: PASS");
      else      $display("QUEUE SORT TEST: FAIL");
      $finish;
   end
endmodule
