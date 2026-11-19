class C;
  rand bit x;

  function automatic int disable_all();
    this.constraint_mode(0);
    return 1;
  endfunction

  function automatic int indirect();
    return disable_all();
  endfunction

  constraint direct_c { x == disable_all(); }
  constraint indirect_c { x == indirect(); }
endclass

module test;
  C obj;
  initial begin
    obj = new;
    if (!obj.randomize())
      $fatal(1, "randomize failed");
  end
endmodule
