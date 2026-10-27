class base;
  int x;
endclass

class derived extends base;
  int y;
endclass

module test;
  initial begin
    base base2, base3;
    derived original, copied;

    original = new;
    original.x = 3;
    original.y = 7;
    base2 = original;
    base3 = new base2;

    if (base3.x !== 3)
      $fatal(1, "shallow copy lost inherited property x");
    if (!$cast(copied, base3))
      $fatal(1, "shallow copy lost derived dynamic type");
    if (copied.y !== 7)
      $fatal(1, "shallow copy lost derived property y");

    copied.x = 9;
    if (original.x !== 3)
      $fatal(1, "shallow copy aliases source properties");
    $display("PASS dyn_type");
  end
endmodule
