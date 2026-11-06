typedef struct packed { logic [1:0] a; bit b; } item_t;

module top;
  item_t [1:0] p;
  item_t [1:0][2:1] q;

  initial begin
    p = '0;
    q = '0;
    #0;
    $probe_issue1279;
    $finish;
  end
endmodule
