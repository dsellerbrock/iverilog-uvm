module test;
  class item_t;
    rand bit [7:0] values[2][3];
    rand bit [7:0] total;
    rand bit [7:0] item; // The reduction iterator shadows this property.
    bit fail;

    constraint reduced {
      item == 201;
      total == 18;
      total == values[0].sum() with (item * 2);
      if (fail) total == 19;
    }
  endclass

  initial begin
    item_t obj;
    bit [7:0] saved[6];
    bit [7:0] saved_total;
    int observed;
    obj = new;
    if (!obj.randomize() || obj.total != 18 || obj.item != 201)
      $fatal(1, "active selected sum/shadow failed total=%0d item=%0d",
             obj.total, obj.item);
    observed = (obj.values[0][0] * 2) + (obj.values[0][1] * 2)
             + (obj.values[0][2] * 2);
    if (observed != 18)
      $fatal(1, "active selected sum numeric mismatch: %0d", observed);
    saved[0] = obj.values[0][0];
    saved[1] = obj.values[0][1];
    saved[2] = obj.values[0][2];
    saved[3] = obj.values[1][0];
    saved[4] = obj.values[1][1];
    saved[5] = obj.values[1][2];
    saved_total = obj.total;
    obj.fail = 1;
    if (obj.randomize()) $fatal(1, "contradiction succeeded");
    if (obj.values[0][0] != saved[0] || obj.values[0][1] != saved[1]
        || obj.values[0][2] != saved[2] || obj.values[1][0] != saved[3]
        || obj.values[1][1] != saved[4] || obj.values[1][2] != saved[5]
        || obj.total != saved_total)
      $fatal(1, "failed active reduction solve changed state");
    $display("PASSED");
  end
endmodule
