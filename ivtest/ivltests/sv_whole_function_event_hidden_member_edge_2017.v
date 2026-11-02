module sv_whole_function_event_hidden_member_edge;
  class H;
    int idx;
  endclass

  H h = new;
  logic [3:0] bus = 4'b0010;
  int fired = 0;

  function automatic int pick();
    return h.idx;
  endfunction

  initial begin
    h.idx = 0;
    fork begin
      @(posedge bus[pick()]);
      fired = 1;
    end join_none
    #1 h.idx = 1;
    #1;
    if (fired != 1)
      $fatal(1, "function-body class member did not update event selector");
    $display("PASS whole-function-hidden-member-edge");
    $finish;
  end
endmodule
