// `static const` is legal, but repeated qualifiers and the mutually exclusive
// local/protected access qualifiers are not.
class bad_static_const_qualifiers;
  static static const int duplicate_static = 1;
  local protected const int conflicting_access = 2;
endclass

module test;
endmodule
