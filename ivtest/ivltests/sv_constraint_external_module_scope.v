// IEEE 1800-2017/2023 18.5.1: external constraints are module items in the
// same scope as the class declaration.
module test;
  class X;
    rand bit [3:0] x;
    constraint p;
    extern constraint q;
  endclass

  constraint X::p { x < 4; }
  constraint X::q { x[0] == 1; }

  X obj;
  initial begin
    obj = new;
    repeat (10) begin
      if (!obj.randomize()) $fatal(1, "randomize failed");
      if (!(obj.x inside {1, 3})) $fatal(1, "bad x=%0d", obj.x);
    end
    $display("MOD bad=0");
    $finish;
  end
endmodule
