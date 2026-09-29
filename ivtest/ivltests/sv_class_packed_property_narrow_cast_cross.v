// Narrowing a base can wrap into an invalid index on a nonzero-based word.
class packed_narrow_cast_holder;
  bit [1:0][4:3] data;
  function void check(input bit lane);
    bit got;
    got = data[0][2'(3'(lane + 3'd3)) -: 1];
    data[0][2'(3'(lane + 3'd3)) -: 1] = 1'b1;
  endfunction
endclass
module sv_class_packed_property_narrow_cast_cross;
  packed_narrow_cast_holder h;
  initial begin h = new; h.check(1); end
endmodule
