module top;
  initial begin
    #5 $exit;
    $display("AFTER %0t", $time);
  end
  initial #10 $display("LATE %0t", $time);
endmodule
