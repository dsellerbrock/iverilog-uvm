module sv_continuous_struct_driver_conflict_fail;
  typedef struct { logic a; logic [3:0] b; } s_t;
  s_t src, duplicate, proc_after, proc_before;
  assign duplicate = src;
  assign duplicate = src;
  assign proc_after = src;
  initial proc_after.a = 1'b1;
  initial proc_before.a = 1'b0;
  assign proc_before = src;
endmodule
