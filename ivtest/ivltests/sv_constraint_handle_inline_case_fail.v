// EXPECT COMPILE ERROR: IEEE 1800-2017/2023 18.3 prohibits four-state constraint operators.
class inline_case_leaf;
endclass
class inline_case_root;
  rand bit value;
  inline_case_leaf handle_value;
endclass
module main;
  inline_case_root r;
  inline_case_leaf expected;
  initial begin
    r = new;
    expected = new;
    r.handle_value = expected;
    if (r.randomize() with { handle_value === local::expected; })
      $fatal(1, "illegal inline case equality accepted");
  end
endmodule
