// Dynamic indexed ranges in an ascending inner dimension match a signal.
module sv_class_packed_property_ascending_dynamic_slice;
  class holder;
    bit [1:0][0:7] data;

    function bit [3:0] read_up(bit lane);
      return data[0][lane+1 +: 4];
    endfunction
    function bit [3:0] read_down(bit lane);
      return data[0][lane+5 -: 4];
    endfunction
    function void write_up(bit lane, bit [3:0] value);
      data[0][lane+1 +: 4] = value;
    endfunction
    function void write_down(bit lane, bit [3:0] value);
      data[0][lane+5 -: 4] = value;
    endfunction
  endclass

  holder h;
  bit [1:0][0:7] reference;
  initial begin
    h = new;
    h.data = 16'ha5c3;
    reference = 16'ha5c3;
    if (h.read_up(0) !== reference[0][1 +: 4]
        || h.read_up(1) !== reference[0][2 +: 4]
        || h.read_down(0) !== reference[0][5 -: 4]
        || h.read_down(1) !== reference[0][6 -: 4])
      $fatal(1, "ascending dynamic read");
    h.write_up(0, 4'h9);
    reference[0][1 +: 4] = 4'h9;
    h.write_down(1, 4'h2);
    reference[0][6 -: 4] = 4'h2;
    if (h.data !== reference
        || h.read_up(0) !== reference[0][1 +: 4]
        || h.read_down(1) !== reference[0][6 -: 4])
      $fatal(1, "ascending dynamic write/read: %h %h", h.data, reference);
    $display("PASSED");
  end
endmodule
