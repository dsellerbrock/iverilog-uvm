program p1;
  initial begin
    #5 $display("P1 %0t", $time);
    $exit;
    $display("NOT_REACHED");
  end
  initial begin
    #20 $display("P1B_NOT_REACHED");
  end
endprogram

module top;
  initial #100 $display("TOP %0t", $time);
endmodule
