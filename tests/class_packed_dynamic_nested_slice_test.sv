// IEEE 1800-2017 7.4.6 / 11.5: variable indices and an indexed part
// select on a multidimensional packed class property are one partial write.
module class_packed_dynamic_nested_slice_test;
  class holder;
    bit [3:0][31:0] data;
    function void clear_byte(int i);
      data[i[3:2]][i[1:0]*8+7 -: 8] = 8'h00;
    endfunction
  endclass

  holder h;
  initial begin
    h = new;
    h.data = '1;
    h.clear_byte(5);
    if (h.data[1] == 32'hffff_00ff
        && h.data[0] == 32'hffff_ffff
        && h.data[2] == 32'hffff_ffff
        && h.data[3] == 32'hffff_ffff)
      $display("PASS: class multidimensional dynamic nested slice");
    else
      $display("FAIL: class packed data=%h", h.data);
    $finish;
  end
endmodule
