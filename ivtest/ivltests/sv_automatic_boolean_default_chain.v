// IEEE 1800-2017/2023 6.8,6.21,9.4.2: default values seed the expression.
module main;
  task automatic watch();
    bit parent_value;
    time origin;
    origin = $time;
    begin
      bit child_value;
      bit mask;
      mask = 1;
      fork
        begin
          @(negedge ((parent_value | child_value) & mask));
          if ($time - origin != 3) $fatal(1, "false default expression edge %0t", $time - origin);
        end
        begin
          #1; parent_value = 0; child_value = 0;
          #1; parent_value = 1;
          #1; parent_value = 0;
        end
      join
    end
  endtask
  initial begin
    repeat (3) begin
      fork watch(); watch(); join
    end
    $display("PASSED");
    $finish(0);
  end
  initial begin #100; $fatal(1, "timeout"); end
endmodule
