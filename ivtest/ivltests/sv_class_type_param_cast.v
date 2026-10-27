// A parameterized class type may qualify its type parameter in a cast.
// IEEE 1800-2017/2023 8.5 shows vector #(3)::T'(3.45) as legal.
class vector #(parameter width = 7, type T = int);
endclass

module test;
  initial begin
    if (vector #(3)::T'(3.45) !== 3
        || vector #(3, byte)::T'(3.45) !== 8'sd3)
      $display("FAILED");
    else
      $display("PASSED");
  end
endmodule
