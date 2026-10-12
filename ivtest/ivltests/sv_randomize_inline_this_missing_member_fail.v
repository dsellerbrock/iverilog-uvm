class randomize_target_min;
  rand bit [3:0] clen;
endclass

class randomize_caller_min;
  randomize_target_min req;
  int no_such_member;

  function new();
    req = new;
  endfunction

  function void bad();
    void'(req.randomize() with { this.clen == 4'd3; });
    void'(req.randomize() with { this.no_such_member == 4'd12; });
  endfunction
endclass

module main;
  randomize_caller_min caller;
  initial begin
    caller = new;
    caller.bad();
  end
endmodule
