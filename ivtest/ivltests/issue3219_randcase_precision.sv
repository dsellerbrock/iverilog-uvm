module top;
  byte unsigned a = 8'hff, b = 8'h01;
  byte signed neg = -2, two = 2, one = 1;
  int first, second, signed_zero, signed_other;

  initial begin
    repeat (100) begin
      randcase
        a + b: first++;
        1: second++;
      endcase
      randcase
        (neg / two) + one: signed_zero++;
        1: signed_other++;
      endcase
    end
    if (first != 0 || second != 100 ||
        signed_zero != 0 || signed_other != 100)
      $fatal(1, "incorrect weights: %0d,%0d %0d,%0d",
             first, second, signed_zero, signed_other);
    $display("PASS randcase precision");
  end
endmodule
