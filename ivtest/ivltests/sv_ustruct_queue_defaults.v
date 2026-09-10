package types;
  typedef struct { int value=37; } item_t;
  typedef item_t items_t[$];
  typedef struct { items_t items; int flag=9; } wrapper_t;
endpackage
module test;
  import types::*;
  item_t direct[$], bounded[$:3];
  items_t alias_q;
  item_t scalar;
  wrapper_t wrapper;
  class holder;
    item_t q[$];
    items_t alias_q;
    const item_t constant_q[$];
    static item_t static_q[$];
    wrapper_t nested;
  endclass
  holder a,b;
  task automatic use_queue(int n);
    item_t local_q[$];
    static item_t retained[$];
    item_t item;
    if (local_q.size()!=0 || retained.size()!=n) $fatal(1,"lifetime");
    if (item.value!=37) $fatal(1,"scalar default lost");
    local_q.push_back(item); retained.push_back(item);
    item.value=99;
    if (local_q[0].value!=37 || retained[n].value!=37) $fatal(1,"copy");
  endtask
  initial begin
    a=new; b=new;
    if (direct.size() || bounded.size() || alias_q.size() || wrapper.items.size()) $fatal(1,"module empty");
    if (wrapper.flag!=9 || scalar.value!=37) $fatal(1,"nested scalar defaults");
    if (a.q.size() || a.alias_q.size() || a.constant_q.size() || a.static_q.size() || a.nested.items.size()) $fatal(1,"class empty");
    a.q.push_back(scalar);
    if (b.q.size()!=0 || a.q[0].value!=37 || a.nested.flag!=9) $fatal(1,"object lifetime");
    use_queue(0); use_queue(1);
    $display("PASSED"); $finish(0);
  end
endmodule
