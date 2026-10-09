// A runtime range must clip within the selected packed class-property element.
class packed_dynamic_cross_holder;
  bit [1:0][15:0] data;
  function void check();
    bit [1:0] lane;
    logic [7:0] got, expected_read;
    bit [1:0][15:0] expected;
    data = 32'hABCD_5678;
    expected = data;
    for (int i = 0; i < 4; i++) begin
      lane = i[1:0];
      got = data[0][lane*8+3 -: 8];
      expected_read = expected[0][lane*8+3 -: 8];
      if (got !== expected_read)
        $fatal(1, "class-property read lane %0d: %h expected %h",
               lane, got, expected_read);
      data[0][lane*8+3 -: 8] = 8'hA5;
      expected[0][lane*8+3 -: 8] = 8'hA5;
      if (data !== expected)
        $fatal(1, "class-property write lane %0d: %h expected %h",
               lane, data, expected);
    end
  endfunction
endclass
module sv_class_packed_property_dynamic_slice_cross;
  packed_dynamic_cross_holder h;
  initial begin h = new; h.check(); $display("PASSED"); end
endmodule
