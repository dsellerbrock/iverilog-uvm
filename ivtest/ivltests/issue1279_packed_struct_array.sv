module top;
  typedef struct packed { logic [1:0] a; bit b; } item_t;
  item_t [1:0] p;
  item_t [1:0][1:0] q;

  initial begin
    p = '0;
    q = '0;
    #0;
    $probe;
    $finish;
  end
endmodule
