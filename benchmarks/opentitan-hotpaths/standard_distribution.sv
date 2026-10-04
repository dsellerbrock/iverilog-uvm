module top;
  bit [7:0] value;
  int count_1;
  int count_2;
  int count_8;
  int count_9;
  int count_10;
  int count_11;
  int i;

  initial begin
    count_1 = 0;
    count_2 = 0;
    count_8 = 0;
    count_9 = 0;
    count_10 = 0;
    count_11 = 0;
    for (i = 0; i < 2000; i = i + 1) begin
      if (!std::randomize(value) with {
            value dist { 1 := 4, 2 := 2, [8:11] :/ 1 };
          })
        $fatal(1, "std::randomize failed");
      case (value)
        1: count_1 = count_1 + 1;
        2: count_2 = count_2 + 1;
        8: count_8 = count_8 + 1;
        9: count_9 = count_9 + 1;
        10: count_10 = count_10 + 1;
        11: count_11 = count_11 + 1;
        default: $fatal(1, "distribution produced value outside support: %0d", value);
      endcase
    end
    $display("PASS standard_distribution calls=%0d bins={1:%0d,2:%0d,8:%0d,9:%0d,10:%0d,11:%0d}",
             i, count_1, count_2, count_8, count_9, count_10, count_11);
    $finish;
  end
endmodule
