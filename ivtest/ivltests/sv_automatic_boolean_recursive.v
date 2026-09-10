module main;
  int done;
  task automatic watch(input int depth);
    logic parent_value;
    time origin;
    origin=$time;
    parent_value=depth[0];
    #1;
    begin
      bit local_zero;
      fork
        begin
          @(posedge ((parent_value | local_zero) ^ local_zero));
          if ($time-origin != (depth[0] ? 3 : 2))
            $fatal(1,"recursive expression %0d woke at %0t",depth,$time-origin);
          done++;
        end
        begin #1; parent_value=1'bx; #1; parent_value=1; end
        begin if(depth) watch(depth-1); end
      join
    end
  endtask
  initial begin
    repeat(3) begin
      fork watch(2); watch(3); join
    end
    if(done!=21) $fatal(1,"missing recursive check %0d",done);
    $display("PASSED");
    $finish(0);
  end
  initial begin #100; $fatal(1,"timeout"); end
endmodule
