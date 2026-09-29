// A bounded dynamic byte range stays inside one packed property element.
module sv_class_packed_property_dynamic_nested_slice;
  class holder;
    bit [3:0][31:0] data;
    int calls;

    function void clear_byte(int i);
      data[i[3:2]][i[1:0]*8+7 -: 8] = 8'h00;
    endfunction

    function bit [7:0] read_byte(int i);
      return data[i[3:2]][i[1:0]*8+7 -: 8];
    endfunction

    function bit [1:0] next_lane();
      calls++;
      return 2'd2;
    endfunction

    function void write_once();
      data[0][next_lane()*8+7 -: 8] = 8'h12;
    endfunction
  endclass

  holder h;
  logic [1:0] unknown_lane;
  initial begin
    h = new;
    h.data = '1;
    h.clear_byte(5);
    if (h.data[1] !== 32'hffff_00ff || h.read_byte(5) !== 8'h00)
      $fatal(1, "middle byte read/write: %h", h.data[1]);
    h.clear_byte(12);
    h.clear_byte(15);
    if (h.data[3] !== 32'h00ff_ff00)
      $fatal(1, "low/high byte bounds: %h", h.data[3]);
    h.write_once();
    if (h.calls != 1 || h.data[0] !== 32'hff12_ffff)
      $fatal(1, "index evaluated more than once: calls=%0d data=%h",
             h.calls, h.data[0]);
    unknown_lane = 2'bx1;
    h.data[2][unknown_lane*8+7 -: 8] = 8'h00;
    if (h.data[2] !== 32'hffff_ffff)
      $fatal(1, "unknown index changed property: %h", h.data[2]);
    $display("PASSED");
  end
endmodule
