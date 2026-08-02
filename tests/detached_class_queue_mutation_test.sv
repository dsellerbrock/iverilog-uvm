interface detached_class_queue_clock_if;
  logic clk = 1'b0;

  always #1 clk = ~clk;

  task wait_n_clks(int count);
    repeat (count) @(posedge clk);
  endtask
endinterface

class detached_class_queue_item;
  byte data;
endclass

class detached_class_queue_base;
  virtual task record_after_two_waits(byte data);
  endtask

  task dispatch_record(byte data);
    record_after_two_waits(data);
  endtask
endclass

class detached_class_queue_owner extends detached_class_queue_base;
  virtual detached_class_queue_clock_if vif;
  bit enabled;
  detached_class_queue_item pending[$];
  detached_class_queue_item processing[$];
  detached_class_queue_item completed[$];

  function new(virtual detached_class_queue_clock_if vif);
    this.vif = vif;
    enabled = 1'b1;
  endfunction

  task enqueue_after_delay(byte data);
    detached_class_queue_item item = new;

    fork begin
      int pending_size;
      bit move_item;

      vif.wait_n_clks(1);
      item.data = data;
      pending.push_back(item);
      pending_size = pending.size();
      move_item = enabled && processing.size() == 0 && pending.size() > 0;

      vif.wait_n_clks(2);
      if (enabled && processing.size() == 0 && pending.size() > 0) begin
        processing.push_back(pending.pop_front());
      end

      if (move_item) pending_size--;
    end join_none
  endtask

  virtual task record_after_two_waits(byte data);
    detached_class_queue_item item = new;

    fork begin
      vif.wait_n_clks(1);
      item.data = data;
      vif.wait_n_clks(2);
      completed.push_back(item);
    end join_none
  endtask
endclass

module detached_class_queue_mutation_test;
  detached_class_queue_clock_if clock_if();
  detached_class_queue_owner owner;

  initial begin
    owner = new(clock_if);
    owner.enqueue_after_delay(8'h63);
    clock_if.wait_n_clks(4);

    if (owner.pending.size() != 0) begin
      $fatal(1, "pending queue retained %0d item(s)", owner.pending.size());
    end
    if (owner.processing.size() != 1) begin
      $fatal(1, "processing queue has %0d item(s)", owner.processing.size());
    end
    if (owner.processing[0].data != 8'h63) begin
      $fatal(1, "processing queue data is %0h", owner.processing[0].data);
    end

    owner.dispatch_record(8'h11);
    owner.dispatch_record(8'h22);
    owner.dispatch_record(8'h33);
    clock_if.wait_n_clks(1);
    @(negedge clock_if.clk);
    owner.dispatch_record(8'h44);
    clock_if.wait_n_clks(4);
    if (owner.completed.size() != 4) begin
      $fatal(1, "overlapping detached calls completed %0d item(s)", owner.completed.size());
    end

    $display("PASSED: detached fork preserved delayed class queue mutations");
    $finish;
  end
endmodule
