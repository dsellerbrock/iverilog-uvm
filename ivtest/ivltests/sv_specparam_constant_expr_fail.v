// IEEE 1800-2017 6.20.5: specparams are not general constants.
module test;
  specparam delay = 50;
  parameter p = delay + 2;
endmodule
