module test;
  class item_t;
    int value;

    function new(int value);
      this.value = value;
    endfunction
  endclass

  class holder_t;
    item_t items[$];

    function item_t top();
      if (items.size() == 0)
        return null;
      return items[$];
    endfunction
  endclass

  initial begin
    holder_t holder;
    item_t item;

    holder = new;

    item = new(10);
    holder.items.push_back(item);
    item = new(20);
    holder.items.push_back(item);

    if (holder.top() == null) begin
      $display("FAILED: missing top item");
      $finish(1);
    end

    if (holder.top().value != 20) begin
      $display("FAILED: wrong top item value %0d", holder.top().value);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
