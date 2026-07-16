// M14 negative: checker declarations (IEEE 1800-2017 17) are not
// implemented and must be diagnosed with an explicit sorry (previously
// a bare "syntax error"), not silently accepted.
module top;
  logic clk=0, a=1;
  checker my_chk(logic c, logic x);
    assert property (@(posedge c) x);
  endchecker
  initial $finish(0);
endmodule
