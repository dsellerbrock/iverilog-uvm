class item;
  int value;
endclass
module sv_const_handle_rebind_fail;
  const item handle = new;
  initial handle = null;
endmodule
