// IEEE 1800-2017/2023 19.5: covergroup expressions allow only constant
// system function calls.
module top;
  bit [3:0] value = 3;
  covergroup cg;
    cp: coverpoint value { bins invalid = {$random}; }
  endgroup
endmodule
