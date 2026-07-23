// M1B-5 negative: a VARIABLE bit/indexed-part write into an ASCENDING packed
// vector class property ([lo:hi]) is not yet supported and must be loudly
// diagnosed (sorry), never silently miscompiled. Constant selects and
// variable selects on the usual descending [hi:lo] vectors ARE supported.
// IEEE 1800-2017 7.4.6.
module class_property_ascending_variable_write;
  class R; logic [8:15] v; endclass   // ascending packed range
  initial begin
    automatic R r = new;
    automatic int i = 2;
    r.v = 8'h00;
    r.v[i] = 1'b1;   // variable index into ascending vector -> reject loudly
    $display("v=%h", r.v);
  end
endmodule
