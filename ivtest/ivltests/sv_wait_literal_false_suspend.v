// An explicit wait(0) is a legal, intentional permanent suspension. The
// compiler must preserve that behavior without diagnosing the unmistakable
// literal-zero idiom as accidental constant folding.
module sv_wait_literal_false_suspend;
  bit returned;

  initial begin
    fork
      begin
        wait (0);
        returned = 1'b1;
      end
    join_none

    #1;
    if (returned) begin
      $display("FAILED: wait(0) returned");
      $finish(1);
    end
    $display("PASSED");
  end
endmodule
