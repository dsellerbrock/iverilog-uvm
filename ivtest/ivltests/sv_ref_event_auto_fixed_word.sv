module sv_ref_event_auto_fixed_word;
  task automatic wait_for_edge(const ref logic word_arg,
                               input time expected, input logic new_value);
    @(posedge word_arg);
    if ($time != expected || word_arg !== new_value)
      $fatal(1, "word edge at %0t with %b, expected %0t with %b",
             $time, word_arg, expected, new_value);
  endtask

  int string_wakes;
  task automatic wait_for_string(const ref string word_arg, input time expected);
    @(word_arg);
    if ($time != expected || word_arg != "changed")
      $fatal(1, "string word changed at %0t, expected %0t", $time, expected);
    string_wakes++;
  endtask

  task automatic detach_string_watch(input time delay_to_change);
    string arr[2];
    time expected;
    arr[1] = "initial";
    expected = $time + delay_to_change;
    fork
      wait_for_string(arr[1], expected);
      begin
        #1 arr[0] = "unwatched";
        #(delay_to_change - 1) arr[1] = "changed";
      end
    join_none
  endtask

  task automatic relay_edge(const ref logic word_arg,
                            input time expected, input logic new_value);
    wait_for_edge(word_arg, expected, new_value);
  endtask

  task automatic watch_word(input time delay_to_edge, input logic new_value);
    logic arr[2];
    time expected;
    arr[0] = 0;
    arr[1] = 0;
    expected = $time + delay_to_edge;
    fork
      relay_edge(arr[1], expected, new_value);
      begin
        #1 arr[0] = 1;
        #(delay_to_edge - 1) arr[1] = new_value;
      end
    join
  endtask

  task automatic set_low_bits(ref logic [3:0] word_arg);
    word_arg[1:0] = 2'b11;
    #2;
  endtask

  task automatic relay_write(ref logic [3:0] word_arg);
    set_low_bits(word_arg);
  endtask

  task automatic check_write(input logic [3:0] start_value);
    logic [3:0] arr[2];
    arr[1] = start_value;
    fork
      relay_write(arr[1]);
      begin
        #1;
        if (arr[1] !== (start_value | 4'b0011))
          $fatal(1, "forwarded write not visible before return");
      end
    join
  endtask

  task automatic recursive_write(input int depth, ref logic [3:0] parent_word);
    logic [3:0] arr[2];
    arr[1] = 4'b1000;
    if (depth == 0) begin
      parent_word[1:0] = 2'b01;
      if (parent_word !== 4'b1001 || arr[1] !== 4'b1000)
        $fatal(1, "recursive ref did not select the caller's word");
    end else begin
      recursive_write(depth - 1, arr[1]);
      if (arr[1] !== 4'b1001)
        $fatal(1, "recursive write did not update the caller");
    end
  endtask

  function automatic bit [3:0] write_bit_word(ref bit [3:0] word_arg);
    word_arg[1:0] = 2'b01;
    return word_arg;
  endfunction

  task automatic check_function;
    bit [3:0] arr[2];
    bit [3:0] result;
    arr[1] = 4'b1100;
    result = write_bit_word(arr[1]);
    if (result !== 4'b1101 || arr[1] !== 4'b1101)
      $fatal(1, "function ref did not update the two-state array word");
  endtask

  task automatic static_word(input bit writer);
    static logic arr[2];
    if (writer) arr[1] = 1;
    else begin
      arr[1] = 0;
      relay_edge(arr[1], $time + 1, 1'b1);
    end
  endtask

  logic [3:0] unused_word;
  initial begin
    fork
      // A 0-to-X posedge also checks that the relay sampled the initial 0.
      watch_word(2, 1'bx);
      watch_word(3, 1'b1);
    join
    check_write(4'b1000);
    check_write(4'b0100);
    recursive_write(1, unused_word);
    check_function();
    fork
      static_word(0);
      #1 static_word(1);
    join
    detach_string_watch(2);
    detach_string_watch(3);
    #4;
    if (string_wakes != 2)
      $fatal(1, "expected two string word changes, got %0d", string_wakes);
    $display("PASSED");
    $finish(0);
  end

  initial #20 $fatal(1, "fixed-array word edge did not wake its ref waiter");
endmodule
