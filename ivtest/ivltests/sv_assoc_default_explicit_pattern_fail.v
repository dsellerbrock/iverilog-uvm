// Explicit associative keys in an assignment pattern are legal, but require
// keyed construction rather than the positional queue-pattern lowering.
module main;
  localparam string LIVE = "live";
  int values[string] = '{LIVE:11, default:22};
endmodule
