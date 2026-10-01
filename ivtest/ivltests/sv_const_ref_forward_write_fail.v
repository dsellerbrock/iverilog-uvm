module sv_const_ref_forward_write_fail;
  task automatic illegal_write(const ref int value);
    value = 1;
  endtask
  int value;
  initial illegal_write(value);
endmodule
