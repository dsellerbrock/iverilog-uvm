class C;
  var type(this) explicit_handle, second_handle;
`ifdef TEST_2023
  type(this) implicit_handle;
  function void check();
    explicit_handle = this;
    second_handle = explicit_handle;
    implicit_handle = second_handle;
    if (implicit_handle != this) $fatal(1, "self type mismatch");
  endfunction
`endif
endclass
module issue3625;
  C c;
  initial begin
    c = new;
`ifdef TEST_2023
    c.check();
`endif
    $display("PASS issue3625");
  end
endmodule
