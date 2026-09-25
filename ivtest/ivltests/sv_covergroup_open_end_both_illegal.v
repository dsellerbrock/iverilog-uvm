// Neither IEEE 1800-2017 nor 1800-2023 permits [$:$].
module test;
  covergroup cg with function sample(bit [7:0] value);
    cp: coverpoint value { bins invalid = {[$:$]}; }
  endgroup
  cg c = new;
  initial begin
    c.sample(0);
    $display("SHOULD NOT COMPILE");
  end
endmodule
