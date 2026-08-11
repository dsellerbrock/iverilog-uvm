class invalid_fields;
  int plain;
  rand int valid;
endclass

module test;
  invalid_fields obj = new;
  int query_plain;
  int query_missing;

  initial begin
    obj.plain.rand_mode(0);
    query_plain = obj.plain.rand_mode();
    obj.missing.rand_mode(0);
    query_missing = obj.missing.rand_mode();
  end
endmodule
