module top;
  function int F; int member; member = 4; return 1; endfunction
  initial begin
    void'(F());
    $display("%s 13.4.1.fn_name_hier_scope (%0d)",
             F.member == 4 ? "PASS" : "FAIL", F.member);
  end
endmodule
