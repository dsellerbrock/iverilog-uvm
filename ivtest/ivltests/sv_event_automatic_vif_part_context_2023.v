interface automatic_vif_part_context_if;
  logic gate;
endinterface

class automatic_vif_part_holder;
  virtual automatic_vif_part_context_if vif;
endclass

module automatic_vif_part_context;
  automatic_vif_part_context_if bus();
  automatic_vif_part_holder holder;
  int wakes[2];
  int recursive_wakes;
  bit done;

  task automatic sibling(input int id, input bit change);
    logic [3:0] value = 0;
    #1; // This fixture starts after the static holder's VIF is fully bound.
    begin : descendant
      int retained;
      fork : lifetime
        begin
          @(posedge (value[2] & holder.vif.gate));
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
    logic [3:0] value = 0;
    #1; // Isolate automatic context routing from the separate startup test.
    if (depth != 0)
      recurse(depth - 1);
    begin : descendant
      int retained;
      fork
        begin
          @(posedge (value[2] & holder.vif.gate));
          recursive_wakes++;
          retained++;
        end
        begin #1 value = 4'b0x00; #1 value = 4'b0100; end
      join
      if (retained != 1)
        $fatal(1, "recursive descendant state lost depth=%0d", depth);
    end
  endtask

  initial begin
    holder = new;
    holder.vif = bus;
    bus.gate = 1;
    #1;
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
