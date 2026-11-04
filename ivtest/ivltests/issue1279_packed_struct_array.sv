module top;
  typedef struct packed { logic [1:0] a; bit b; } item_t;
  item_t [1:0] p;
  item_t [1:0][3:2] md;

  initial begin
    p = '0;
    md = '0;
    #0;
    $probe_issue1279_packed_struct_array;
    $finish;
  end
endmodule
