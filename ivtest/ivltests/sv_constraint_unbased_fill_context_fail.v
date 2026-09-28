// Fill expressions without a representable comparison context must fail.
module main;
  bit [3:0] value;
  initial begin
    if (std::randomize(value) with { value inside {[0:'1]}; }) $fatal;
    if (std::randomize(value) with { value inside {('1 - 1'b1)}; }) $fatal;
    if (std::randomize(value) with { value == 'x; }) $fatal;
  end
endmodule
