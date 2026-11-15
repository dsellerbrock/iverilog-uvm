// IEEE 1800-2023 8.30.1: "The parameter type T shall be a class type; all
// other types shall result in a compiler error."
module top;
   weak_reference#(int) w;
   initial begin
      w = new(5);
      $display("FAILED");
   end
endmodule
