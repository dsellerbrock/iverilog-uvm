module sv_forward_typedef_kind_mismatch_fail;
  typedef enum wrong_kind_t;
  typedef struct { int member; } wrong_kind_t;
endmodule
