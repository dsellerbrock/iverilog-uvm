module test;
  class item_t;
    rand bit [7:0] values[1:0][0:2];
    randc bit [3:0] i;
    randc bit [3:0] j;
    bit fail;

    constraint property_values { i == 12; j == 13; }
    constraint matrix_values {
      foreach (values[i,j]) {
        soft (i == 0);
        values[i][j] == i * 10 + j;
      }
      foreach (values[i]) soft (i == 1);
      foreach (values[,j]) soft (j == 0);
      if (fail) values[1][0] == 99;
    }
  endclass

  initial begin
    item_t obj;
    bit [7:0] saved[6];
    obj = new;
    if (!obj.randomize() || obj.i != 12 || obj.j != 13
        || obj.values[1][0] != 10 || obj.values[1][1] != 11
        || obj.values[1][2] != 12 || obj.values[0][0] != 0
        || obj.values[0][1] != 1 || obj.values[0][2] != 2)
      $fatal(1, "multidimensional foreach/shadow result failed");
    saved[0] = obj.values[1][0];
    saved[1] = obj.values[1][1];
    saved[2] = obj.values[1][2];
    saved[3] = obj.values[0][0];
    saved[4] = obj.values[0][1];
    saved[5] = obj.values[0][2];
    obj.fail = 1;
    if (obj.randomize()) $fatal(1, "multidimensional contradiction succeeded");
    if (obj.values[1][0] != saved[0] || obj.values[1][1] != saved[1]
        || obj.values[1][2] != saved[2] || obj.values[0][0] != saved[3]
        || obj.values[0][1] != saved[4] || obj.values[0][2] != saved[5]
        || obj.i != 12 || obj.j != 13)
      $fatal(1, "failed multidimensional foreach changed state");
    $display("PASSED");
  end
endmodule
