module sv_string_return_character_bounds;
  logic [127:0] mixed, high;
  function automatic string update(input logic [127:0] index, input byte value);
    update = "ABC";
    update[index] = value;
  endfunction
  function automatic string empty_update();
    empty_update = "";
    empty_update[0] += 1;
  endfunction
  initial begin
    mixed = '0; mixed[1:0] = 2'b1x;
    high = '0; high[100] = 1'b1;
    if (update(mixed, "Z") != "ABZ") $fatal(1, "mixed int conversion");
    if (update(high, "Z") != "ZBC") $fatal(1, "high int truncation");
    if (update(-1, "Z") != "ABC") $fatal(1, "negative index");
    if (update(1, 0) != "ABC") $fatal(1, "zero byte");
    if (empty_update() != "") $fatal(1, "empty return");
    $display("PASSED");
  end
endmodule
