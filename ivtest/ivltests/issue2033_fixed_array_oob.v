module issue2033_fixed;
  class constant_read;
    rand bit s;
    rand bit v[1];
    constraint c { v[1] <= s; }
  endclass

  class bad_read;
    int index;
    rand bit s;
    rand bit v[2:3];
    constraint c { v[index] <= s; }
  endclass

  class symbolic_read;
    rand int index;
    rand bit v[2:3];
    bit enable;
    int forced;
    constraint c { index == forced; if (enable) v[index] <= 1; }
  endclass

  class valid_read;
    int index;
    rand bit v[2:3];
    constraint c { v[index] == 1; }
  endclass

  initial begin
    constant_read constant_oob;
    bad_read bad;
    symbolic_read symbolic;
    valid_read valid;
    constant_oob = new;
    bad = new;
    symbolic = new;
    valid = new;

    if (constant_oob.randomize()) $fatal(1, "constant invalid read succeeded");
    bad.index = 4;
    if (bad.randomize()) $fatal(1, "invalid relational read succeeded");
    symbolic.index = 2;
    symbolic.forced = 4;
    symbolic.enable = 1;
    if (symbolic.randomize()) $fatal(1, "invalid symbolic read succeeded");
    if (symbolic.index != 2) $fatal(1, "failed solve changed index");
    symbolic.enable = 0;
    if (!symbolic.randomize() || symbolic.index != 4)
      $fatal(1, "disabled guard failed");
    valid.index = 3;
    if (!valid.randomize() || valid.v[3] != 1)
      $fatal(1, "valid read failed");
    $display("PASS");
  end
endmodule
