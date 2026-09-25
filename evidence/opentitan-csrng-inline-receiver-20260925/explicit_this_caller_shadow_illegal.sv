class csrng_item_min;
  rand bit [3:0] clen;
endclass

class caller_min;
  csrng_item_min req;
  int no_such_member;
  function new(); req = new; endfunction
  function void bad();
    // A nonmember must be diagnosed, not silently captured or dropped.
    void'(req.randomize() with { this.no_such_member == 4'd12; });
  endfunction
endclass

module top;
  caller_min c;
  initial begin
    c = new;
    c.bad();
  end
endmodule
