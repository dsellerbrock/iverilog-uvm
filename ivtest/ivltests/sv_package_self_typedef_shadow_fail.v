package self_shadow_fail_pkg;
  typedef logic [7:0] word_t;
  class self_shadow_fail_pkg;
    typedef logic [3:0] other_t;
  endclass
  class probe;
    self_shadow_fail_pkg::word_t prop;
  endclass
endpackage
module main; endmodule
