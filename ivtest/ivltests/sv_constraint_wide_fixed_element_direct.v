package wide_constants;
  parameter logic [64:0] TARGET = 65'h1_55555555_aaaaaaaa;
endpackage
class direct_item;
  rand logic [64:0] value[2];
  constraint exact_values {
    value[0] == wide_constants::TARGET;
    value[1] == value[0] + 65'd1;
  }
endclass
module test;
  initial begin
    direct_item item;
    item = new;
    // The active logic elements begin as X and must be solved, not treated as
    // an invalid accept-current value.
    if (!item.randomize() ||
        item.value[0] !== 65'h1_55555555_aaaaaaaa ||
        item.value[1] !== 65'h1_55555555_aaaaaaab)
      $fatal(1, "direct wide fixed elements failed");
    $display("PASSED");
  end
endmodule
