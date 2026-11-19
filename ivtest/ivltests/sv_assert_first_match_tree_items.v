// IEEE 1800-2017/2023 16.9.8, 16.10, 16.11
module sv_assert_first_match_tree_items;
  bit clk, start, early, late;
  int data;
  logic [3:0] nibble = 15;
  int passes, next_passes, covers, calls, completed;
  bit [2:1] seen, done;

  property check_value(int value);
    int x, y;
    @(posedge clk)
      first_match((start ##1 early) or (start ##2 late),
                  x = value, y = x + 1) |-> (early && y == 8);
  endproperty
  assert property (check_value(data))
    passes++;
    else $fatal(1, "wrong first_match endpoint or consequent local");

  property check_next(local input int x);
    @(posedge clk)
      first_match((start ##1 early) or (start ##2 late), x += 2)
      |=> (late && x == 8);
  endproperty
  assert property (check_next(6))
    next_passes++;
    else $fatal(1, "wrong local formal at the nonoverlapped consequent");

  task automatic record(input int id, sampled_data, wide);
    if ($time != 11 || id < 1 || id > 2 || seen[id] ||
        sampled_data != 7 || data != 99 || wide != 30)
      $fatal(1, "invalid Reactive call at %0t: id=%0d sampled=%0d live=%0d wide=%0d",
             $time, id, sampled_data, data, wide);
    seen[id] = 1;
    calls++;
    #8;
  endtask

  function automatic void record_after(input int id, sampled_data);
    if ($time != 19 || id < 11 || id > 12 || !seen[id-10] || done[id-10] ||
        sampled_data != 7 || data != 100)
      $fatal(1, "lost source order or snapshot: id=%0d sampled=%0d live=%0d",
             id, sampled_data, data);
    done[id-10] = 1;
    completed++;
  endfunction

  sequence tied;
    int id;
    first_match(((start, id = 1) ##1 early) or
                ((start, id = 2) ##[1:2] (early || late)),
                record(id, data, nibble + nibble), id += 10,
                record_after(id, data));
  endsequence
  cover sequence (@(posedge clk) tied) covers++;

  always @(posedge clk) begin
    if (early) data <= 99;
    if (late) data <= 100;
  end

  task tick;
    #5 clk = 1;
    #1 clk = 0;
  endtask

  initial begin
    $assertvacuousoff(0);
    start = 1;
    tick();
    start = 0;
    early = 1;
    data = 7;
    tick();
    if (passes != 1 || next_passes || covers != 2 || calls != 2 ||
        seen != 2'b11 || completed)
      $fatal(1, "early counts: pass=%0d cover=%0d call=%0d done=%0d",
             passes, covers, calls, completed);

    early = 0;
    late = 1;
    tick();
    late = 0;
    tick();
    if (passes != 1 || next_passes != 1 || covers != 2 || calls != 2 ||
        completed != 2 || done != 2'b11)
      $fatal(1, "final counts: pass=%0d cover=%0d call=%0d done=%0d",
             passes, covers, calls, completed);
    $display("PASS");
    $finish(0);
  end
endmodule
