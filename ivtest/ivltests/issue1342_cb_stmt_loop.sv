module top;
  event ev;
  integer i, repeat_body;
  initial begin
    repeat_body = 0;
    repeat (3) begin
      repeat_body = repeat_body + 1;
      continue;
    end
    i = 0;
    while (i < 2) i = i + 1;
    for (i = 0; i < 2; i = i + 1) begin end
    i = 0;
    forever begin
      i = i + 1;
      if (i == 2) break;
    end
    @ev;
    #1;
    $finish;
  end
  initial begin
    #0 -> ev;
  end
endmodule
