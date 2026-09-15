module sv_const_mixed_equality_fail;
  class item; endclass
  function automatic int illegal(item value);
    return value == "a";
  endfunction
  localparam int VALUE = illegal(null);
endmodule
