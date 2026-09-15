class wide_leaf;
  rand bit [64:0] value[2];
  rand logic signed [95:0] signed_value[1];
endclass
class wide_item;
  rand wide_leaf leaf;
  constraint exact_values {
    leaf.value[0] == 65'h1_00000000_00000005;
    leaf.value[1] == 65'h0_12345678_9abcdef0;
    leaf.signed_value[0] == -96'sh1_00000000_00000003;
  }
  function new; leaf = new; endfunction
endclass
module test;
  initial begin
    wide_item item;
    item = new;
    if (!item.randomize()) $fatal(1, "wide randomize failed");
    if (item.leaf.value[0] !== 65'h1_00000000_00000005 ||
        item.leaf.value[1] !== 65'h0_12345678_9abcdef0 ||
        item.leaf.signed_value[0] !== -96'sh1_00000000_00000003)
      $fatal(1, "wide fixed element transport lost bits");
    $display("PASSED");
  end
endmodule
