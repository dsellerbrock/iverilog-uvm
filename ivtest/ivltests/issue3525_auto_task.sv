module issue3525_auto_task;
  int b, star, comb1, comb2;
  int values[2];
  int index = 0;

  task automatic calculate(input int x, output int y);
    y = x + 1;
  endtask

  always @* calculate(b, star);
  always_comb calculate(b, comb1);
  always_comb calculate(b, comb2);
  always_comb calculate(b, values[index]);

  initial begin
    #1;
    if (star !== 0 || comb1 !== 1 || comb2 !== 1 || values[0] !== 1)
      $fatal(1, "incorrect initial values: %0d %0d %0d %0d", star, comb1, comb2, values[0]);
    b = 2;
    #1;
    if (star !== 3 || comb1 !== 3 || comb2 !== 3 || values[0] !== 3)
      $fatal(1, "incorrect values after input change");
    index = 1;
    #1;
    if (values[1] !== 3)
      $fatal(1, "output index did not trigger the task call");
    $display("PASS");
  end
endmodule
