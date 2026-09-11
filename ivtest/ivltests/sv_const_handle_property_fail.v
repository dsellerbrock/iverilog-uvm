class item;
  const int marker = 9;
endclass
module sv_const_handle_property_fail;
  const item handle = new;
  initial handle.marker = 10;
endmodule
