class holder_t;
  int x = 7;
  int dd[][];
endclass

module top;
  initial begin
    automatic holder_t h = new;
    h.dd = new[2];
    $display("%p", h);
    h.dd[0] = new[1];
    $display("%p", h);
    h.dd[0][0] = 42;
    $display("%p", h);
    h.dd[1] = new[0];
    $display("%p", h);
  end
endmodule
