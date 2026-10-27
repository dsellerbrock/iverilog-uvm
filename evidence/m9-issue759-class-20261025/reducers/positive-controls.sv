module main;
  class base; endclass
  class derived extends base; endclass
  base b;
  derived d;
  int i;
  function automatic base get_base(); return d; endfunction
  initial begin
    b = d;
    b = null;
    b = get_base();
    i = (b == null);
    if (b) i = 1;
  end
endmodule
