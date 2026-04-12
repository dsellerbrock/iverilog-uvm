module test;
  int seen;

  class item_t;
    int id;

    function new(int value = 0);
      id = value;
    endfunction
  endclass

  class hopper_t;
    item_t q[$];

    function void put(item_t item);
      q.push_back(item);
    endfunction

    virtual task get(output item_t item);
      item = q.pop_front();
    endtask

    task run(output int seen);
      item_t got;
      this.get(got);
      seen = (got == null) ? -1 : got.id;
    endtask
  endclass

  class traced_hopper_t extends hopper_t;
    virtual task get(output item_t item);
      super.get(item);
    endtask
  endclass

  initial begin
    traced_hopper_t hopper;
    item_t expected_item;

    hopper = new;
    expected_item = new;
    expected_item.id = 17;
    hopper.put(expected_item);
    hopper.run(seen);

    if (seen !== 17) begin
      $display("FAIL seen=%0d", seen);
      $finish(1);
    end

    $display("PASS");
  end
endmodule
