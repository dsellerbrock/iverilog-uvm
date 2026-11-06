module issue2544_union_percent_p_2023;
  typedef union {
    int a;
    int b;
  } u_t;

  u_t u;
  u_t q[$];

  initial begin
    u.a = 5;
    q.push_back(u);
    $display("%p", u);
    $display("%p", q);
  end
endmodule
