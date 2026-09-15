package write_state_pkg;
  string storage = "ABC";
endpackage
module sv_const_string_character_write_package_fail;
  import write_state_pkg::*;
  function automatic string illegal_write();
    storage[0] = "Z";
    return "OK";
  endfunction
  localparam string VALUE = illegal_write();
endmodule
