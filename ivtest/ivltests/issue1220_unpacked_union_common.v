module issue1220_unpacked_union_common;
  typedef struct { bit [7:0] tag; bit [3:0] a; } left_t;
  typedef struct { bit [7:0] tag; bit [3:0] b; } right_t;
  typedef union { left_t left; right_t right; } u_t;
  u_t u;

  initial begin
    u.left = '{8'h5a, 4'hc};
    if (u.right.tag !== 8'h5a)
      $fatal(1, "common prefix read got %h", u.right.tag);
    u.left.tag = 8'ha6;
    if (u.right.tag !== 8'ha6)
      $fatal(1, "updated common prefix read got %h", u.right.tag);
    $display("PASS");
  end
endmodule
