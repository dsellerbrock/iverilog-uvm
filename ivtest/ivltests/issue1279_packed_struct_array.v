module top;
  typedef struct packed { logic [1:0] a; bit b; } item_t;
  item_t [1:0] p;
  item_t [1:0][3:2] q;
  typedef struct packed { bit flag; } bit_item_t;
  bit_item_t [1:0] r;
  initial begin
    p = '0;
    q = '0;
    r = '0;
    #0;
    $probe_packed_struct_array;
    $finish;
  end
endmodule
