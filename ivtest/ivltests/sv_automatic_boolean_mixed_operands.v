// IEEE 1800-2017/2023 6.21 and 9.4.2: compute each activation's expression.
module main;
  time observed[2];
  task automatic watch(input bit id);
    bit parent_value;
    time origin;
    origin = $time;
    parent_value = 1;
    #1;
    begin
      bit child_value;
      child_value = id;
      fork
        begin
          @(negedge (parent_value | child_value));
          observed[id] = $time - origin;
        end
        begin
          #1; parent_value = 0;
          #1; child_value = 0;
        end
      join
    end
  endtask
  initial begin
    repeat (3) begin
      fork watch(0); watch(1); join
      if (observed[0] != 2 || observed[1] != 3)
        $fatal(1, "mixed operand history %0t,%0t", observed[0], observed[1]);
    end
    $display("PASSED");
    $finish(0);
  end
  initial begin #100; $fatal(1, "timeout"); end
endmodule
