package issue3626_pkg;
  parameter int nums[] = {1, 2, 3};
endpackage
module issue3626_fixed_param_size;
  parameter string words[2] = {"a", "b"};
  initial begin
    $display("%0d", words.size());
    $display("%0d", issue3626_pkg::nums.size());
  end
endmodule
