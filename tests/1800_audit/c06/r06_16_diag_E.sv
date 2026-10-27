module t; string a = "xyz", b = "QRS", s; byte c; bit [7:0] v = 8'h41;
  initial begin
    a[0] = b; $display("E str2elem a='%s'", a);
    s = v; $display("E implicit8 s='%s' len=%0d", s, s.len());
    s = 16'h4142; $display("E implicit16 s='%s' len=%0d", s, s.len());
    c = b; $display("E str2byte c=%0d", c);
  end
endmodule
