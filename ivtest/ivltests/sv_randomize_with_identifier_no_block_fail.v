class target_c;
  rand int value;
endclass

module test;
  target_c item;
  function target_c get_item(); return item; endfunction
  initial begin
    item = new;
    item.randomize() with (value);
    get_item().randomize() with (value);
  end
endmodule
