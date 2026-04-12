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

  int seen[$];

  initial begin
    hopper_t hopper;
    item_t first;
    item_t second;
    item_t ph;

    hopper = new;
    first = new(1);
    second = new(2);
    hopper.put(first);
    hopper.put(second);

    repeat (2) begin
      hopper.get(ph);
      fork
        automatic item_t phase = ph;
        begin
          seen.push_back(phase.id);
        end
      join_none
      #0;
    end

    #0;

    if (seen.size() != 2) begin
      $display("FAILED -- seen.size=%0d expected 2", seen.size());
      $finish(1);
    end

    if (seen[0] != 1 || seen[1] != 2) begin
      $display("FAILED -- seen=%0d,%0d expected 1,2", seen[0], seen[1]);
      $finish(1);
    end

    $display("PASSED");
  end
endmodule
