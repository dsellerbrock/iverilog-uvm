class fixed_integral_state;
  int a[-2:0];
  int idx;

  constraint selected {
    if (idx inside {[-2:0]})
      a[idx] inside {[12:17]};
  }
  constraint constant_index { a[-2] inside {[10:20]}; }
endclass

module test;
  fixed_integral_state obj;
  initial begin
    obj = new;
    obj.a[-2] = 15;
    obj.a[-1] = 25;
    obj.idx = -2;
    if (!obj.randomize(null)) $fatal(1, "Selected 15 must pass");
    obj.idx = -1;
    if (obj.randomize(null)) $fatal(1, "Selected 25 must fail");
    obj.idx = -3;
    if (!obj.randomize(null)) $fatal(1, "Guard must skip invalid index");
    obj.a[-2] = 21;
    if (obj.randomize(null)) $fatal(1, "Constant index must see updated 21");
    $display("PASSED");
  end
endmodule
