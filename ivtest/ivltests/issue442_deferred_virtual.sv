// IEEE 1800-2017/2023 16.4, 16.4.1 and 8.20.
package issue442_actions;
  bit source_done;
  int task_started, task_finished;
  int function_seen[2];
  int nonvirtual_seen;

  class base;
    int id;

    virtual task report_task(input int value, ref int live,
                             input logic [3:0] words[2]);
      $fatal(1, "base task called");
    endtask

    virtual function void report_function(input int value, const ref int live,
                                          input int words[2][2]);
      $fatal(1, "base function called");
    endfunction

    function void report_nonvirtual(input int value);
      if (!source_done || id != 7 || value != 7)
        $fatal(1, "nonvirtual report got receiver %0d and value %0d", id, value);
      nonvirtual_seen++;
    endfunction
  endclass

  class derived extends base;
    task report_task(input int value, ref int live,
                     input logic [3:0] words[2]);
      if (!source_done || id != 7 || value != 7 || live != 41 ||
          words[0] !== 4'b10xz || words[1] !== 4'ha)
        $fatal(1, "task report got receiver %0d, value %0d, ref %0d, words %b %b",
               id, value, live, words[0], words[1]);
      task_started++;
      live = 42;
      #0;
      if (function_seen[0] != 1 || function_seen[1] != 1 ||
          words[0] !== 4'b10xz)
        $fatal(1, "task did not resume with its own frame after Reactive");
      task_finished++;
    endtask

    function void report_function(input int value, const ref int live,
                                  input int words[2][2]);
      if (!source_done || id != value || value < 11 || value > 12 ||
          live != 51 || words[0][1] != value + 20 || words[1][0] != value + 30)
        $fatal(1, "function report got receiver %0d, value %0d, ref %0d, words %0d %0d",
               id, value, live, words[0][1], words[1][0]);
      function_seen[value - 11]++;
    endfunction
  endclass
endpackage

module issue442_deferred_virtual;
  import issue442_actions::*;
  base receiver;
  derived original;
  int value;
  int task_ref = 40;
  int function_ref = 50;
  logic [3:0] task_words[2];
  int function_words[2][2];
  int direct_seen;

  task report_direct(input int input_value);
    if (!source_done || input_value != 7)
      $fatal(1, "direct report got value %0d", input_value);
    direct_seen++;
  endtask

  initial begin
    original = new;
    original.id = 7;
    receiver = original;
    value = 7;
    task_words = '{4'b10xz, 4'ha};
    assert #0 (1) receiver.report_task(value, task_ref, task_words);
    assert #0 (1) receiver.report_nonvirtual(value);
    assert #0 (1) report_direct(value);

    for (int id = 11; id <= 12; id++) begin
      original = new;
      original.id = id;
      receiver = original;
      value = id;
      function_words[0][1] = id + 20;
      function_words[1][0] = id + 30;
      assert #0 (0) else receiver.report_function(value, function_ref, function_words);
    end
    receiver = new;
    original = null;
    value = 99;
    task_words[0] = 0;
    function_words[1][0] = 0;
    task_ref <= 41;
    function_ref <= 51;
    source_done = 1;

    #1;
    if (task_started != 1 || task_finished != 1 || task_ref != 42 ||
        function_seen[0] != 1 || function_seen[1] != 1 ||
        direct_seen != 1 || nonvirtual_seen != 1)
      $fatal(1, "missing, duplicated, or unbound deferred action");
    $display("PASS");
  end
endmodule
