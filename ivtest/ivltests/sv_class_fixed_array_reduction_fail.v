// Strict legality checks for IEEE 1800-2017 7.12.3 reductions.
class invalid_fixed_reductions;
  string texts[0:1];
  int matrix[0:1][2:4];
  int values[0:1];

  function void probe;
    int result;
    result = texts.sum();
    result = matrix.sum();
    result = values.sum(1) with (item);
    result = values.sum(item);
  endfunction
endclass

class invalid_constraint_reduction;
  rand int matrix[0:1][2:4];
  constraint bad_shape_c { matrix.sum() == 0; }
endclass

module main;
  invalid_fixed_reductions value;
  invalid_constraint_reduction constrained_value;
  initial begin
    value = new;
    constrained_value = new;
    value.probe();
  end
endmodule
