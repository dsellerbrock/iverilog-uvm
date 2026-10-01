module sv_const_ref_forward_writable_fail;
  task automatic writable(ref int value);
    value = 1;
  endtask
  task automatic forward(const ref int value);
    writable(value);
  endtask
  int value;
  initial forward(value);
endmodule
