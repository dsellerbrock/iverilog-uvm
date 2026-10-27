module n10_11_alias_duplicate_pair;
  wire a, b;
  alias a = b;
  alias b = a;
endmodule
