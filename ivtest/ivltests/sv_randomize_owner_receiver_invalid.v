// A member absent from both the randomized object and caller is illegal.
class invalid_inline_item;
  rand bit [3:0] clen;
endclass

class invalid_inline_owner;
  invalid_inline_item req;
  function new(); req = new; endfunction
  function void check();
    void'(req.randomize() with { req.no_such_member == 4'd12; });
  endfunction
endclass

module sv_randomize_owner_receiver_invalid;
  invalid_inline_owner owner;
  initial begin
    owner = new;
    owner.check();
  end
endmodule
