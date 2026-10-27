module top;
  class B;
    int x;
    virtual function int y_value(); return -1; endfunction
  endclass
  class D extends B;
    int y;
    virtual function int y_value(); return y; endfunction
  endclass
  B bh, copied;
  D d1;
  initial begin
    d1 = new; d1.x = 3; d1.y = 8; bh = d1;
    copied = new bh;
    $display("COPY_RETURNED");
    if (copied.x != 3 || copied.y_value() != 8) $fatal(1, "S3 derived type or properties lost");
    copied.x = 4;
    if (d1.x != 3 || d1.y != 8) $fatal(1, "S3 copy aliases source");
    $display("PASS S3 base handle source=%0d/%0d copy=%0d/%0d", d1.x, d1.y, copied.x, copied.y_value());
  end
endmodule
