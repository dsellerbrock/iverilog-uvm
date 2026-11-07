module issue2717_cond_string_cast;
  logic [15:0] v = 16'h4142;
  byte b = 8'h43;
  bit c = 1;
  string s;

  initial begin
    s = c ? string'(v) : string'(b);
    $display("%s", s);
    c = 0;
    s = c ? string'(v) : string'(b);
    $display("%s", s);
  end
endmodule
