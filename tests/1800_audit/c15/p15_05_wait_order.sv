// IEEE 1800-2017/2023 §15.5.4: wait_order observes a, b, then c.
module test;
  event a, b, c;
  bit passed = 0;
  initial begin
    fork
      begin
        #10 -> a;
        #10 -> b;
        #10 -> c;
      end
      begin
        wait_order(a, b, c) begin
          passed = 1;
          $display("PASS 15.5.4 wait_order at %0t", $time);
        end else begin
          $fatal(1, "FAIL 15.5.4: events arrived out of order");
        end
      end
    join
  end
  initial begin
    #40;
    if (!passed) $fatal(1, "FAIL 15.5.4: wait_order timed out");
  end
endmodule
