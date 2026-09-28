// Bare calls with a required formal are illegal even if later formals default.
class needs_arg;
  function int f(int x, int y = 1); return x + y; endfunction
  function int bad_bare(); return f; endfunction
endclass

class holder;
  needs_arg p;
  function new(); p = new; endfunction
  function int bad_property(); return p.f; endfunction
endclass

module main;
  holder h;
  initial begin
    h = new;
    $display("%0d", h.p.bad_bare() + h.bad_property());
  end
endmodule
