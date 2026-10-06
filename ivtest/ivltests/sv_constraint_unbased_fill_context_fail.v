// Fill expressions that the binary constraint solver cannot represent fail.
module main;
  bit [3:0] value;
  initial begin
    if (std::randomize(value) with { value inside {('1 - 1'b1)}; }) $fatal;
    if (std::randomize(value) with { value inside {[0:'x]}; }) $fatal;
    if (std::randomize(value) with { value == 'x; }) $fatal;
  end
endmodule
