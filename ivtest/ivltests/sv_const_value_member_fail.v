module sv_const_value_member_fail;
  typedef struct packed {int value;} value_t;
  const value_t frozen = '{value:7};
  initial frozen.value = 8;
endmodule
