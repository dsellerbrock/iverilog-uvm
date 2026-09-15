module test;
  class item_t;
    bit [7:0] values[2][3];
    rand bit [7:0] total;
    bit signed [7:0] signed_values[2][2];
    rand bit signed [7:0] signed_total;
    rand bit [7:0] item; // The with iterator must shadow this property.
    bit fail;

    function new;
      values[0][0] = 2;
      values[0][1] = 3;
      values[0][2] = 4;
      values[1][0] = 21;
      values[1][1] = 22;
      values[1][2] = 23;
      signed_values[0][0] = -5;
      signed_values[0][1] = 2;
      signed_values[1][0] = 40;
      signed_values[1][1] = 41;
    endfunction
    constraint reduced {
      item == 201;
      total == values[0].sum() with (item * 2);
      signed_total == signed_values[0].sum();
      if (fail) total == 99;
    }
  endclass

  initial begin
    item_t obj;
    bit [7:0] saved_total;
    bit signed [7:0] saved_signed_total;
    obj = new;
    if (!obj.randomize() || obj.total != 18 || obj.item != 201
        || obj.signed_total != -3)
      $fatal(1, "selected sum/iterator shadow failed total=%0d item=%0d",
             obj.total, obj.item);
    saved_total = obj.total;
    saved_signed_total = obj.signed_total;
    obj.fail = 1;
    if (obj.randomize()) $fatal(1, "contradiction succeeded");
    if (obj.values[0][0] != 2 || obj.values[0][1] != 3
        || obj.values[0][2] != 4 || obj.values[1][0] != 21
        || obj.values[1][1] != 22 || obj.values[1][2] != 23
        || obj.total != saved_total
        || obj.signed_total != saved_signed_total)
      $fatal(1, "failed reduction solve changed state");
    $display("PASSED");
  end
endmodule
