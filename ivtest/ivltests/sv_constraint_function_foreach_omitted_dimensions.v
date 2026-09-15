module test;
  class item_t;
    rand bit [7:0] values[2][3];
    randc bit [3:0] i;
    randc bit [3:0] j;
    bit fail;
    constraint names { i == 12; j == 13; }
    constraint omitted {
      foreach (values[i]) soft (i == 0);
      foreach (values[,j]) values[0][j] == j + 5;
      if (fail) values[0][2] == 99;
    }
  endclass
  initial begin
    item_t obj;
    bit [7:0] a, b, c;
    obj = new;
    if (!obj.randomize() || obj.i != 12 || obj.j != 13
        || obj.values[0][0] != 5 || obj.values[0][1] != 6
        || obj.values[0][2] != 7)
      $fatal(1, "omitted/trailing foreach iterator failed");
    a = obj.values[0][0]; b = obj.values[0][1]; c = obj.values[0][2];
    obj.fail = 1;
    if (obj.randomize() || obj.values[0][0] != a
        || obj.values[0][1] != b || obj.values[0][2] != c)
      $fatal(1, "omitted-dimension rollback failed");
    $display("PASSED");
  end
endmodule
