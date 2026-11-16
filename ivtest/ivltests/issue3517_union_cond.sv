module issue3517_union_cond;
  typedef union tagged { int Number; void Empty; } item_t;
  item_t a, b, same, different;
  logic c;
  bit choose = 1;
  initial begin
    a = tagged Number (7);
    b = tagged Empty;
    same = tagged Number (7);
    different = tagged Number (9);
    c = 1;
    $display("selected %p %p", c ? a : b, !c ? a : b);
    c = 0;
    $display("reversed %p %p", c ? a : b, !c ? a : b);
    c = 1'bx;
    $display("unknown %p %p %p", c ? a : same, c ? a : b,
             c ? b : b);
    c = 1'bz;
    $display("highz %p", c ? a : different);
    c = 1;
    $display("nested %p", c ? (c ? a : b) : b);
    c = 1'bx;
    $display("nested unknown %p", c ? (choose ? a : b) :
                                      (choose ? b : a));
  end
endmodule
