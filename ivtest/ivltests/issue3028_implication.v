module issue3028_implication;
  logic [1:0] lhs;
  logic rhs, result, expected;
  logic [1:0] values [0:3];
  int left_calls, right_calls;

  function automatic logic [1:0] left_value();
    left_calls++;
    return lhs;
  endfunction

  function automatic logic right_value();
    right_calls++;
    return rhs;
  endfunction

  initial begin
    values[0] = 2'b00;
    values[1] = 2'b11;
    values[2] = 2'b0x;
    values[3] = 2'b0z;
    for (int i = 0; i < 4; i++) begin
      for (int j = 0; j < 4; j++) begin
        lhs = values[i];
        rhs = values[j][0];
        left_calls = 0;
        right_calls = 0;
        result = left_value() -> right_value();
        expected = !lhs || rhs;
        if (result !== expected || left_calls != 1 ||
            right_calls != ((lhs === 2'b00) ? 0 : 1))
          $fatal(1, "lhs=%b rhs=%b result=%b expected=%b calls=%0d,%0d",
                 lhs, rhs, result, expected, left_calls, right_calls);
      end
    end
    $display("PASS");
  end
endmodule
