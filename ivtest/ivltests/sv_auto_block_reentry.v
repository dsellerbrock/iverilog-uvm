// IEEE 1800-2017/2023 6.21 and 6.8: default initialization belongs
// to each automatic block entry, including class-method loop bodies.
class reentry_item;
  int value;
endclass

class reentry_driver;
  task run();
    for (int i = 0; i < 3; i++) begin
      bit done;
      logic [7:0] unknown_value;
      real amount;
      string label;
      int queue[$];
      reentry_item item;
      int initialized = 7;
      static int count = 0;
      if (done !== 0 || unknown_value !== 8'hxx || amount != 0.0 ||
          label != "" || queue.size() != 0 || item != null ||
          initialized != 7 || count != i)
        $fatal(1, "class block entry %0d retained state", i);
      done = 1;
      unknown_value = 0;
      amount = 1.5;
      label = "used";
      queue.push_back(i);
      item = new;
      initialized = 99;
      count++;
      #1;
    end
  endtask
endclass

module main;
  reentry_driver driver;
  int captured[3];
  int wakes;

  function automatic int recursive(input int depth);
    begin
      int saved = depth;
      if (depth == 0) return saved;
      return saved + recursive(depth - 1);
    end
  endfunction

  task automatic exits();
    for (int i = 0; i < 4; i++) begin
      bit used;
      if (used) $fatal(1, "continue retained block state");
      used = 1;
      if (i < 2) continue;
      break;
    end
    begin
      int value = 9;
      if (value == 9) return;
    end
    $fatal(1, "return failed");
  endtask

  task automatic event_blocks();
    repeat (3) begin
      event ready;
      fork
        begin #1; ->ready; end
        begin @ready; wakes++; end
      join
    end
  endtask

  task automatic run_blocks();
    for (int i = 0; i < 3; i++) begin : entry
      int value;
      int saved = i;
      if (value !== 0) $fatal(1, "task block entry retained state");
      value = i + 10;
      fork
        begin
          #4;
          captured[saved] = value;
        end
      join_none
      #1;
    end
    wait fork;
  endtask

  initial begin
    driver = new;
    driver.run();
    run_blocks();
    exits();
    exits();
    if (recursive(4) != 10) $fatal(1, "recursive frame corrupted");
    event_blocks();
    if (wakes != 3) $fatal(1, "event frame corrupted");
    for (int i = 0; i < 3; i++)
      if (captured[i] != i + 10)
        $fatal(1, "detached capture aliased at %0d", i);
    $display("PASSED");
  end
endmodule
