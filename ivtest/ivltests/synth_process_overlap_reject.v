`begin_keywords "1800-2012"

module main;
  logic first;
  logic second;
  logic [1:0] result;

  // The structural process-output boundary must not conceal a genuine
  // same-bit overlap. This remains an illegal pair of procedural drivers.
  always_comb result[0] = first;
  always_comb result[0] = second;

  assign result[1] = 1'b0;
endmodule

`end_keywords
