// IEEE 1364 functions do not permit nonblocking assignments. A named block
// inside the function must not hide the enclosing function context.
module function_nba_verilog_fail;
  reg side_effect;

  function integer bad;
    input dummy;
    begin : nested
      side_effect <= 1'b1;
      bad = 0;
    end
  endfunction

  initial $display("%0d", bad(1'b0));
endmodule
