module test;
  class item_t;
    int id;

    function new(int value);
      id = value;
    endfunction
  endclass

  class hopper_t;
    item_t q[$];

    function void put(item_t item);
      q.push_back(item);
    endfunction

    task get(output item_t item);
      item = q.pop_front();
    endtask
  endclass

  initial begin
    hopper_t hopper;
    item_t first;
    item_t second;
    item_t got;

    hopper = new;
    first = new(1);
    second = new(2);
    got = new(99);

    hopper.put(first);
    hopper.put(second);

    hopper.get(got);
    if (got != first) begin
      $display("FAILED -- first get returned wrong handle");
      $finish(1);
    end
    if (got.id != 1) begin
      $display("FAILED -- first get id=%0d expected 1", got.id);
      $finish(1);
    end

    hopper.get(got);
    if (got != second) begin
      $display("FAILED -- second get returned wrong handle");
      $finish(1);
    end
    if (got.id != 2) begin
      $display("FAILED -- second get id=%0d expected 2", got.id);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
