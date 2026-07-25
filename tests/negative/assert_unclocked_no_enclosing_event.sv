// M9-10: implicit clock inference (IEEE 1800-2017 16.14.6) takes the
// innermost enclosing procedural event control. Here there is none: the
// assertion is a module item, and the module has no default clocking. There
// is nothing to infer from, so this must stay a loud error -- inventing a
// clock would make the assertion evaluate at moments the user never wrote.
module top;
  logic a = 1, b = 0;
  assert property (a |-> b);
endmodule
