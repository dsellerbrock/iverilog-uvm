module sv_function_background_join_fail;
  class worker;
    function int bad();
      fork bad = 1; join_any
    endfunction
    function void launch();
      fork $display("%0d", bad()); join_none
    endfunction
  endclass
  initial begin
    worker w;
    w = new;
    w.launch();
    #1;
  end
endmodule
