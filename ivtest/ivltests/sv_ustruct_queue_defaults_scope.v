module test;
  typedef class scope_owner;
  class scope_owner;
    typedef struct { int value=13; } item_t;
    typedef item_t queue_t[$];
  endclass
  initial begin
    scope_owner::item_t direct[$];
    scope_owner::queue_t alias_q;
    static scope_owner::item_t explicit_q[$]='{'{41}};
    if (direct.size() || alias_q.size()) $fatal(1,"class typedef queue not empty");
    if (explicit_q.size()!=1 || explicit_q[0].value!=41) $fatal(1,"explicit initialization lost");
    $display("PASSED"); $finish(0);
  end
endmodule
