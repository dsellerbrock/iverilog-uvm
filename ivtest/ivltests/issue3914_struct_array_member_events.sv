// IEEE 1800-2017 7.4.6 / 2023 7.4.5 and both editions 9.4.2.
module issue3914_struct_array_member_events;
  typedef struct { real r; bit spare; } inner_t;
  typedef struct { logic b; bit spare; inner_t inner; logic [1:0] pair; } row_t;
  row_t rows[3:6];
  row_t replacement;
  inner_t inner_replacement;
  int checks = 0;

  task automatic check_time(input int expected, input string name);
    if ($time != expected)
      $fatal(1, "%s woke at %0t, expected %0d", name, $time, expected);
    checks++;
  endtask

  task automatic watch_local(input int delay_to_write);
    row_t local_rows[10:7];
    row_t value;
    int start_time = int'($time);
    fork
      begin : observer
        @(local_rows[8].inner.r) check_time(start_time + delay_to_write, "automatic member");
        @(local_rows[8].inner.r) check_time(start_time + delay_to_write + 1, "automatic replacement");
      end
      begin
        #1 local_rows[7].inner.r = 7.5;
        local_rows[8].inner.spare = 1;
        #(delay_to_write - 1) local_rows[8].inner.r = delay_to_write;
        #1 begin
          value = local_rows[8];
          value.inner.r = 9.5;
          local_rows[8] = value;
        end
      end
    join
  endtask

  initial begin
    fork
      begin
        @(rows[4].b) check_time(2, "selected logic");
        @(rows[4].b) check_time(4, "logic after equal replacement");
        @(rows[4].b) check_time(7, "logic replacement");
      end
      begin
        @(rows[4].inner.r) check_time(2, "nested real");
        @(rows[4].inner.r) check_time(4, "real after equal replacement");
        @(rows[4].inner.r) check_time(6, "real after equal nested replacement");
        @(rows[4].inner.r) check_time(7, "real replacement");
      end
      begin
        #3;
        @(rows[4].pair[0] ^ rows[4].pair[1]) check_time(7, "in-place expression");
      end
      begin
        #5;
        @(rows[4].b ^ rows[4].spare) check_time(8, "replacement expression");
      end
      begin
        watch_local(2);
        watch_local(3);
      end
      watch_local(4);
    join_none

    // The selected element starts untouched. Arming must sample its defaults.
    #1 begin
      rows[3].b = 1;
      rows[5].inner.r = 8.25;
      rows[4].spare = 1;
      rows[4].inner.spare = 1;
      rows[4].pair = 0;
    end
    #1 begin
      rows[4].b = 1;
      rows[4].inner.r = 1.25;
    end
    #1 begin
      replacement = rows[4];
      replacement.spare = 0;
      rows[4] = replacement;
    end
    #1 begin
      rows[4].b = 0;
      rows[4].inner.r = 2.25;
    end
    #1 begin
      inner_replacement = rows[4].inner;
      inner_replacement.spare = 0;
      rows[4].inner = inner_replacement;
      rows[4].pair = 2'b11;
    end
    #1 rows[4].inner.r = 3.25;
    #1 begin
      replacement.b = 1;
      replacement.spare = 1;
      replacement.inner.r = 4.25;
      replacement.pair = 2'b01;
      rows[4] = replacement;
    end
    #1 rows[4].spare = 0;
  end

  initial begin
    #9;
    if (checks !== 15) $fatal(1, "got %0d of 15 expected wakes", checks);
    $display("PASSED");
    $finish(0);
  end
endmodule
