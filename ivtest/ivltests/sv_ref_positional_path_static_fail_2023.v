module sv_ref_positional_path_static_fail;
  int q[$][$];
  task automatic update(ref static int value);
  endtask
  initial update(q[0][1]);
endmodule
