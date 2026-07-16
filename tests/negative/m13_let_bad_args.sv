// M13 negative: let arity and port-name errors must be loud.
module top;
  let f(x, y) = x + y;
  initial begin
    $display("%0d", f(1));            // missing arg, no default
    $display("%0d", f(1, 2, 3));      // too many args
    $display("%0d", f(.z(1), .y(2))); // unknown port name
  end
endmodule
