module test;
  typedef struct { int value=37; } item_t;
  typedef item_t queue_t[$];
  typedef struct { queue_t items; } only_queue_t;
  only_queue_t only_queue;
  const only_queue_t constant_wrapper;
  class holder;
    const only_queue_t only_queue;
  endclass
  holder obj;
  initial begin
    obj=new;
    if (only_queue.items.size() || constant_wrapper.items.size() || obj.only_queue.items.size())
      $fatal(1,"queue-only wrapper did not start empty");
    $display("PASSED"); $finish(0);
  end
endmodule
