// IEEE 1800-2017 7.4.6 / 11.5: a fixed unpacked-array class property
// may have a multidimensional packed element followed by a slice select.
module class_array_packed_slice_test;
  class holder;
    bit [7:0][31:0] key[2];
    function void update();
      key = '{default: '1};
      key[0][7:4] = 32'h0;
      key[1][7:6] = 32'h0;
    endfunction
  endclass

  holder h;
  initial begin
    h = new;
    h.update();
    if (h.key[0][7:4] == 128'h0
        && h.key[0][3:0] == 128'hffff_ffff_ffff_ffff_ffff_ffff_ffff_ffff
        && h.key[1][7:6] == 64'h0)
      $display("PASS: class array multidimensional packed slice");
    else
      $display("FAIL: class array packed slices %h %h", h.key[0], h.key[1]);
    $finish;
  end
endmodule
