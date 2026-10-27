// Loop control remains legal when its target loop is inside the fork.
module test;
  int count;

  initial begin
    fork
      begin
        for (int i = 0; i < 4; i++) begin
          if (i == 1) continue;
          if (i == 3) break;
          count++;
        end
      end
    join

    if (count != 2) begin
      $display("FAILED: count = %0d", count);
      $finish;
    end
    $display("PASSED");
  end
endmodule
