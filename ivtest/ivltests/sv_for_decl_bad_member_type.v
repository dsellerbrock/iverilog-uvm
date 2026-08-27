// IEEE 1800-2017/2023 12.7.1 with Syntax 12-5: a class-scoped member type
// that does not exist must produce one focused diagnostic and a nonzero
// exit, not an assertion or a signal.
module sv_for_decl_bad_member_type;
  class C; endclass
  initial for (C::missing_t x = 0; 0; ) begin end
endmodule
