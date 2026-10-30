module issue1737_unpacked_union_contassign;
  typedef union { bit [7:0] b; int i; } u_t;
  u_t u;
  bit [7:0] cont;

  assign cont = u.b;

  initial begin
    u.b = 8'h12;
    #1;
    if (cont !== 8'h12)
      $fatal(1, "continuous union member read got %h", cont);
    u.b = 8'h34;
    #1;
    if (cont !== 8'h34)
      $fatal(1, "continuous union member update got %h", cont);
    $display("PASSED");
    $finish;
  end
endmodule
