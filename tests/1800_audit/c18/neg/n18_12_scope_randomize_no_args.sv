// IEEE 1800-2017 §18.12 / IEEE 1800-2023 §18.12: no-argument scope randomize.
module test;
  int a = 5, b = 15;
  int success;
  initial begin
    success = std::randomize() with { a < b; };
    if (success !== 1 || a !== 5 || b !== 15)
      $fatal(1, "std::randomize() checker changed satisfied values");

    success = std::randomize() with { a > b; };
    if (success !== 0 || a !== 5 || b !== 15)
      $fatal(1, "std::randomize() checker changed unsatisfied values");
  end
endmodule
