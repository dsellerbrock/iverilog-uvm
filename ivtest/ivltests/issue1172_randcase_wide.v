module top;
  int a, b;

  initial begin
    repeat (600) begin
      randcase
        64'h1_0000_0000: a++;
        64'h1_0000_0000: b++;
      endcase
    end

    if (a < 200 || a > 400 || b < 200 || b > 400)
      $fatal(1, "expected two weighted branches, got a=%0d b=%0d", a, b);
    $display("PASS wide randcase weights");
  end
endmodule
