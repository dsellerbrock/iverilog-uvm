class type_cg #(type T = int);
  T value;
  covergroup cg;
    cp: coverpoint value { bins zero = {0}; bins nonzero = {[1:15]}; }
  endgroup
  function new; cg = new; endfunction
endclass

class width_cg #(parameter int LIMIT = 4);
  int left, right;
  covergroup cg;
    cp_left: coverpoint left {
      bins low = {[0:LIMIT-1]};
      bins high = {[LIMIT:15]};
    }
    cp_right: coverpoint right {
      bins low = {[0:LIMIT-1]};
      bins high = {[LIMIT:15]};
    }
    cross cp_left, cp_right;
  endgroup
  function new; cg = new; endfunction
endclass

module top;
  type_cg #(logic [3:0]) nibble;
  type_cg #(int) integer_value;
  width_cg #(4) narrow;
  width_cg #(8) wide;
  real narrow_coverage, wide_coverage;

  initial begin
    nibble = new;
    integer_value = new;
    narrow = new;
    wide = new;

    nibble.value = 0; nibble.cg.sample();
    nibble.value = 1; nibble.cg.sample();
    integer_value.value = 0; integer_value.cg.sample();
    integer_value.value = 1; integer_value.cg.sample();
    if (nibble.cg.get_inst_coverage() != 100.0 ||
        integer_value.cg.get_inst_coverage() != 100.0)
      $fatal(1, "type-specialized covergroup metadata was lost");

    narrow.left = 1; narrow.right = 1; narrow.cg.sample();
    narrow.left = 5; narrow.right = 5; narrow.cg.sample();
    wide.left = 1; wide.right = 1; wide.cg.sample();
    wide.left = 5; wide.right = 5; wide.cg.sample();
    narrow_coverage = narrow.cg.get_inst_coverage();
    wide_coverage = wide.cg.get_inst_coverage();
    if (narrow_coverage <= wide_coverage)
      $fatal(1, "covergroup bounds were shared: narrow=%0.1f wide=%0.1f",
             narrow_coverage, wide_coverage);

    $display("PASSED");
  end
endmodule
