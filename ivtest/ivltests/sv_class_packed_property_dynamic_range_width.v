// A 33-bit source base and a nonzero packed dimension still select 4 bits.
class packed_dynamic_width_holder;
  bit [1:0][11:4] small_data;
  bit [1:0][64'd2147483655:64'd2147483648] data;
  function bit [3:0] read_small(bit lane);
    return small_data[0][(33'd4 + lane*4 + 3) -: 4];
  endfunction
  function void write_small(bit lane, bit [3:0] value);
    small_data[0][(33'd4 + lane*4 + 3) -: 4] = value;
  endfunction
  function bit [3:0] read_wide(bit lane);
    return data[0][(33'd2147483648 + lane*4 + 3) -: 4];
  endfunction
  function void write_wide(bit lane, bit [3:0] value);
    data[0][(33'd2147483648 + lane*4 + 3) -: 4] = value;
  endfunction
endclass
module sv_class_packed_property_dynamic_range_width;
  packed_dynamic_width_holder h;
  initial begin
    h = new;
    h.small_data = 16'h12a5;
    h.data = 16'h12a5;
    if (h.read_small(0) !== 4'h5 || h.read_small(1) !== 4'ha
        || h.read_wide(0) !== 4'h5 || h.read_wide(1) !== 4'ha)
      $fatal(1, "nonzero-based dynamic read");
    h.write_small(0, 4'h6);
    h.write_wide(1, 4'h3);
    if (h.small_data !== 16'h12a6 || h.data !== 16'h1235)
      $fatal(1, "nonzero-based dynamic write: %h %h",
             h.small_data, h.data);
    $display("PASSED");
  end
endmodule
