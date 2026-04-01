class C;
  static C recycled[$];
  bit a;
  bit b;

  function new();
    a = 0;
    b = 1;
  endfunction

  function void set1();
    a = 1;
  endfunction

  function bit get1();
    return a;
  endfunction

  function bit getb();
    return b;
  endfunction

  function void flush();
    a = 0;
    b = 1;
  endfunction

  function void recycle();
    flush();
    recycled.push_back(this);
  endfunction

  static function C get_avail();
    C c;
    if (recycled.size() > 0)
      c = recycled.pop_back();
    else
      c = new();
    return c;
  endfunction
endclass

module test;
  initial begin
    C c;

    c = C::get_avail();
    c.set1();
    c.recycle();
    c = C::get_avail();

    if (c == null) begin
      $display("FAILED: recycled pop_back returned null");
      $finish_and_return(1);
    end

    if (!c.getb() || c.get1()) begin
      $display("FAILED: recycled object state was not preserved/reset");
      $finish_and_return(2);
    end

    $finish;
  end
endmodule
