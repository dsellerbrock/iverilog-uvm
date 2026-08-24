// This locator receiver is legal under IEEE 1800-2023 7.12.1, but a
// multidimensional fixed property needs a nested iterator value rather than
// the one-dimensional scalar/object materialization implemented here.
class fixed_property_locator_residual;
  int matrix[1:0][1:0];
endclass

module fixed_property_locator_multidimensional_fail;
  fixed_property_locator_residual h;

  initial begin
    h = new;
    $display("%p", h.matrix.find(m) with (m[0] > 0));
  end
endmodule
