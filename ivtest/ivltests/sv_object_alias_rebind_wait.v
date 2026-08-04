module sv_object_alias_rebind_wait;
  class leaf_t;
    int value;
  endclass

  class holder_t;
    leaf_t child;

    function new();
      child = new;
    endfunction
  endclass

  holder_t static_old;
  holder_t static_new;
  holder_t static_alias;
  bit static_old_woke;
  bit static_new_woke;
  int failures;

  task automatic check_automatic_alias;
    holder_t old_h;
    holder_t new_h;
    holder_t alias_h;
    bit old_woke;
    bit new_woke;

    old_h = new;
    new_h = new;
    alias_h = old_h;

    fork
      begin
        wait (alias_h.child.value == 31);
        old_woke = 1;
      end
    join_none

    #1;
    alias_h.child.value = 31;
    #1;
    if (!old_woke || alias_h != old_h) begin
      $display("FAIL automatic nested mutation old_woke=%0d", old_woke);
      failures += 1;
    end

    alias_h = new_h;
    fork
      begin
        wait (alias_h.child.value == 42);
        new_woke = 1;
      end
    join_none

    #1;
    old_h.child.value = 42;
    #1;
    if (new_woke || alias_h != new_h) begin
      $display("FAIL automatic stale alias new_woke=%0d", new_woke);
      failures += 1;
    end

    new_h.child.value = 42;
    #1;
    if (!new_woke || alias_h != new_h) begin
      $display("FAIL automatic rebound alias new_woke=%0d", new_woke);
      failures += 1;
    end
  endtask

  initial begin
    static_old = new;
    static_new = new;
    static_alias = static_old;

    fork
      begin
        wait (static_alias.child.value == 11);
        static_old_woke = 1;
      end
    join_none

    #1;
    static_alias.child.value = 11;
    #1;
    if (!static_old_woke || static_alias != static_old) begin
      $display("FAIL static nested mutation old_woke=%0d", static_old_woke);
      failures += 1;
    end

    static_alias = static_new;
    fork
      begin
        wait (static_alias.child.value == 22);
        static_new_woke = 1;
      end
    join_none

    #1;
    static_old.child.value = 22;
    #1;
    if (static_new_woke || static_alias != static_new) begin
      $display("FAIL static stale alias new_woke=%0d", static_new_woke);
      failures += 1;
    end

    static_new.child.value = 22;
    #1;
    if (!static_new_woke || static_alias != static_new) begin
      $display("FAIL static rebound alias new_woke=%0d", static_new_woke);
      failures += 1;
    end

    check_automatic_alias();

    if (failures) begin
      $display("FAILED failures=%0d", failures);
      $finish_and_return(1);
    end
    $display("PASSED");
    $finish_and_return(0);
  end
endmodule
