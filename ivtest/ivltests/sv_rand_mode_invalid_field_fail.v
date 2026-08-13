class invalid_fields;
  int plain;
  rand int valid;
  rand int dynamic_values[];
  rand int associative_values[int];
endclass

module test;
  invalid_fields obj = new;
  int query_plain;
  int query_missing;
  int query_bad_index;

  initial begin
    obj.plain.rand_mode(0);
    query_plain = obj.plain.rand_mode();
    obj.missing.rand_mode(0);
    query_missing = obj.missing.rand_mode();
    obj.dynamic_values[$].rand_mode(0);
    query_bad_index = obj.dynamic_values[$].rand_mode();
    obj.associative_values[$].rand_mode(0);
    query_bad_index = obj.associative_values[$].rand_mode();
  end
endmodule
