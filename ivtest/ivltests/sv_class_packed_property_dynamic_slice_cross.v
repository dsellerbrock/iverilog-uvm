// A bounded index is still invalid when some values cross the inner word.
class packed_dynamic_cross_holder;
  bit [1:0][15:0] data;
  function void check();
    bit [1:0] lane;
    bit [7:0] got;
    lane = 0;
    got = data[0][lane*8+7 -: 8];
    data[0][lane*8+7 -: 8] = 8'h00;
  endfunction
endclass
module sv_class_packed_property_dynamic_slice_cross;
  packed_dynamic_cross_holder h;
  initial begin h = new; h.check(); end
endmodule
