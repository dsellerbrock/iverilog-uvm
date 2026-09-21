module automatic_part_context_boundaries;
  int wakes[2];
  int recursive_wakes;
  bit done;

  task automatic sibling(input int id, input bit change);
    bit [3:0] value = 0;
    begin : descendant
      int retained;
      fork : lifetime
        begin
          @(posedge value[2]);
          wakes[id]++;
          retained++;
        end
        begin
          #1;
          if (change) begin
            value = 4'b0x00;
            #1 value = 4'b0100;
          end
          #2 disable lifetime;
        end
      join
      if (retained != change)
        $fatal(1, "descendant state leaked id=%0d retained=%0d", id, retained);
    end
  endtask

  task automatic recurse(input int depth);
    bit [3:0] value = 0;
    if (depth != 0)
      recurse(depth - 1);
    begin : descendant
      int retained;
      fork
        begin @(posedge value[2]); recursive_wakes++; retained++; end
        begin #1 value = 4'b0x00; #1 value = 4'b0100; end
      join
      if (retained != 1)
        $fatal(1, "recursive descendant state lost depth=%0d", depth);
    end
  endtask

  initial begin
    fork sibling(0, 1); sibling(1, 0); join
    if (wakes[0] != 1 || wakes[1] != 0)
      $fatal(1, "sibling routing failed wakes=%p", wakes);
    recurse(2);
    if (recursive_wakes != 3)
      $fatal(1, "recursive routing failed wakes=%0d", recursive_wakes);
    $display("PASSED");
    done = 1;
  end
  initial #50 if (!done) $fatal(1, "TIMEOUT wakes=%p recursive=%0d", wakes, recursive_wakes);
endmodule
