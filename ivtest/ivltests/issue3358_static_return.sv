function int choose(int v);
  if (v > 2)
    return 1;
  else if (v == 2)
    return 2;
  else
    return 0;
endfunction

class item;
  rand int a, b, c;
  constraint values { a == choose(3); b == choose(2); c == choose(0); }
endclass

module test;
  item obj;
  initial begin
    obj = new;
    repeat (3) begin
      if (!obj.randomize()) $fatal(1, "randomization failed");
      if (obj.a != 1 || obj.b != 2 || obj.c != 0)
        $fatal(1, "unexpected values: %0d %0d %0d", obj.a, obj.b, obj.c);
    end
    $display("PASS static conditional returns");
  end
endmodule
