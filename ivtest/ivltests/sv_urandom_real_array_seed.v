module top;
  real values[2] = '{1.5, 2.5};
  initial begin
    $display("%0d", $urandom(values[0]));
  end
endmodule
