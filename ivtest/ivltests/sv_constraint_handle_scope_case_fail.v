// EXPECT COMPILE ERROR: IEEE 1800-2017/2023 18.3 prohibits four-state constraint operators.
class std_case_leaf;
endclass
module main;
  bit value;
  std_case_leaf expected;
  initial begin
    expected = new;
    if (std::randomize(value) with { expected !== null; })
      $fatal(1, "illegal std::randomize case inequality accepted");
  end
endmodule
