class issue2512_child;
  rand bit [7:0] d[];
  constraint cd { d.size() == 2; }
endclass

class issue2512_parent;
  rand issue2512_child ch;
  constraint c { ch.d.sum() with (int'(item)) == 50; }
  function new; ch = new; endfunction
endclass

module issue2512_nested_object_array_reduction;
  issue2512_parent p = new;
  initial begin
    if (!p.randomize()) $fatal(1, "randomize failed");
    if (p.ch.d.size() != 2
        || int'(p.ch.d[0]) + p.ch.d[1] != 50)
      $fatal(1, "bad reduction result: size=%0d sum=%0d",
             p.ch.d.size(), int'(p.ch.d[0]) + p.ch.d[1]);
    $display("PASS issue2512 nested object array reduction");
  end
endmodule
