// Static randomization must write the class-scope static signal, so direct
// class access and every object view observe one canonical value.
class static_value_item;
  static rand int shared;
  constraint fixed_value { shared == 17; }
endclass

module test;
  initial begin
    static_value_item first;
    static_value_item second;

    first = new;
    second = new;
    first.shared = 0;
    if (first.randomize() !== 1)
      $fatal(1, "static randomization unexpectedly failed");
    if (first.shared !== 17 || second.shared !== 17)
      $fatal(1, "static randomized value did not reach shared storage");
    $display("PASSED");
  end
endmodule
