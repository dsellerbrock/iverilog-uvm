module issue3715;
  int x, y, z, sibling, self_killed;
  task automatic auto_task;
    begin : blk
      fork begin #20 x = 1; end join_none
      #1 disable blk;
      x = 2;
    end
  endtask
  task static static_task;
    begin : blk
      fork begin #20 y = 1; end join_none
      #1 disable blk;
    end
  endtask
  initial begin
    fork begin #10 sibling = 1; end join_none
    auto_task();
    static_task();
    begin : blk
      fork begin #20 z = 1; end join_none
      #1 disable blk;
    end
    begin : outer
      fork
        begin
          #1 disable outer;
          self_killed = 1;
        end
        begin #20 self_killed = 2; end
      join_none
      #10;
    end
    #30;
    if (x !== 0 || y !== 0 || z !== 0 || self_killed !== 0 || sibling !== 1)
      $fatal(1, "x=%0d y=%0d z=%0d self=%0d sibling=%0d", x, y, z, self_killed, sibling);
    $display("PASS");
  end
endmodule
