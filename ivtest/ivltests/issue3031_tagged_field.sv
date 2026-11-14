module issue3031_tagged_field;
  typedef struct packed {bit [1:0] cc; bit [9:0] addr;} pair_t;
  typedef union tagged {bit [9:0] Jump; pair_t Cond;} u_t;
  pair_t pair, copied;
  u_t u;
  integer idx;
  initial begin
    pair = '{2, 83};
    u = tagged Cond pair;
    copied = u.Cond;
    idx = 1;
    if (copied !== 12'h853 || u.Cond.cc !== 2 ||
        u.Cond.addr !== 83 || u.Cond.cc[idx] !== 1 ||
        u.Cond.addr[5:0] !== 19)
      $fatal(1, "active member field read failed");
    pair = '{1, 10'h2a5};
    u = tagged Cond pair;
    if (u.Cond.cc !== 1 || u.Cond.addr !== 10'h2a5)
      $fatal(1, "updated member field read failed");
    $display("PASS");
  end
endmodule
