module sv_ref_positional_path_type_fail;
  int q[$][$];
  task automatic update(ref shortint value);
  endtask
  initial update(q[0][1]);
endmodule
