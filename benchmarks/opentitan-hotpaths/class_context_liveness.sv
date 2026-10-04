class payload;
  int value;
endclass

module top;
  payload owner;
  payload alias_a;
  payload alias_b;
  int updates;
  int checks;

  task automatic mutate(input payload item, input int next_value);
    fork
      begin
        item.value = next_value;
      end
    join
  endtask

  initial begin
    updates = 0;
    checks = 0;
    repeat (2000) begin
      owner = new;
      alias_a = owner;
      alias_b = alias_a;
      mutate(alias_b, updates);
      if (owner.value != updates || alias_a.value != updates || alias_b.value != updates)
        $fatal(1, "class aliases did not observe the same property update");
      checks = checks + 1;
      owner = null;
      alias_a = null;
      alias_b = null;
      updates = updates + 1;
    end
    $display("PASS class_context_liveness iterations=%0d alias_property_updates=%0d checks=%0d",
             updates, updates, checks);
    $finish;
  end
endmodule
