module sv_typedef_fwd_wrong_kind;
  typedef enum E;
  typedef struct { int a; } E;
endmodule
