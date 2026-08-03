module foreach_selected_dimension_test;
  bit [1:0][7:0] words [2];
  int sum;

  initial begin
    words[0][0] = 8'd11;
    words[0][1] = 8'd23;
    sum = 0;
    foreach (words[0][i]) sum += words[0][i];
    if (sum != 34) begin
      $display("FAIL: selected-dimension foreach sum=%0d", sum);
      $finish(1);
    end
    $display("PASS: foreach iterates a fixed outer-dimension selection");
    $finish;
  end
endmodule
