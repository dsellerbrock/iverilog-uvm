module top;
  bit value;
  covergroup cg;
    cp: coverpoint value { bins invalid[0] = {0,1}; }
  endgroup
endmodule
