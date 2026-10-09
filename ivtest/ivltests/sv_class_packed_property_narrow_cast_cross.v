// Narrowing a dynamic base must preserve the selected element's bounds.
class packed_narrow_cast_holder;
  bit [1:0][4:3] data;
  function void check(input bit lane);
    logic got, expected_read;
    bit [1:0][4:3] expected;
    data = 4'b1001;
    expected = data;
    got = data[0][2'(3'(lane + 3'd3)) -: 1];
    expected_read = expected[0][2'(3'(lane + 3'd3)) -: 1];
    if (got !== expected_read)
      $fatal(1, "class-property read lane %0d: %b expected %b",
             lane, got, expected_read);
    data[0][2'(3'(lane + 3'd3)) -: 1] = 1'b1;
    expected[0][2'(3'(lane + 3'd3)) -: 1] = 1'b1;
    if (data !== expected)
      $fatal(1, "class-property write lane %0d: %h expected %h",
             lane, data, expected);
  endfunction
endclass
module sv_class_packed_property_narrow_cast_cross;
  packed_narrow_cast_holder h;
  initial begin h = new; h.check(0); h.check(1); $display("PASSED"); end
endmodule
