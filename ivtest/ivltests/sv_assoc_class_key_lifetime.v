// An associative array owns its class-handle keys. Automatic variables that
// supplied those keys may go out of scope (or be assigned null) without
// invalidating traversal, lookup, or a whole-array copy.
class assoc_lifetime_key;
  int id;

  function new(input int value);
    id = value;
  endfunction
endclass

module main;
  typedef int value_map_t[assoc_lifetime_key];

  value_map_t source;
  value_map_t copied;
  assoc_lifetime_key iter;
  assoc_lifetime_key selected;
  int failures;

  task automatic check(input logic ok, input string label);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failures = failures + 1;
    end
  endtask

  task automatic add_source_key(input int id);
    assoc_lifetime_key local_key;
    local_key = new(id);
    source[local_key] = id * 10;
    // The associative array must now be the only owner of this key.
    local_key = null;
  endtask

  initial begin
    int count;
    int step;
    bit seen7;
    bit seen8;
    bit seen9;

    add_source_key(7);
    add_source_key(8);
    add_source_key(9);
    check(source.size() == 3, "automatic keys remain distinct and live");

    count = 0;
    if (!source.first(iter)) begin
      check(0, "source first key");
    end else begin
      for (step = 0; step < 3; step = step + 1) begin
        check(iter != null, "source traversal returns a live key");
        if (iter != null) begin
          check(source[iter] == iter.id * 10, "source lookup by traversed key");
          if (iter.id == 8)
            selected = iter;
        end
        count = count + 1;
        if (step < 2)
          check(source.next(iter), "source next key");
      end
      check(!source.next(iter), "source traversal terminates");
    end
    check(count == 3, "source traversal count");
    check(selected != null, "selected source key");

    copied = source;
    check(copied.size() == 3, "whole copy keeps every key");

    // Deleting from one map must release only its ownership and leave the
    // copied map's key and value intact.
    source.delete(selected);
    check(source.size() == 2, "single-key delete changes source only");
    check(!source.exists(selected), "deleted source key is absent");
    check(copied.exists(selected), "copied key survives source delete");
    check(copied[selected] == 80, "copied value survives source delete");
    selected = null;
    iter = null;

    source.delete();
    check(source.size() == 0, "delete-all clears source");

    // Exercise allocator churn after every non-copy handle to the original
    // keys is gone. The copied map must retain all three identities.
    add_source_key(17);
    add_source_key(18);
    add_source_key(19);
    check(source.size() == 3, "new automatic keys remain distinct");
    source.delete();

    count = 0;
    seen7 = 0;
    seen8 = 0;
    seen9 = 0;
    if (!copied.first(iter)) begin
      check(0, "copied first key");
    end else begin
      for (step = 0; step < 3; step = step + 1) begin
        check(iter != null, "copied traversal returns a live key");
        if (iter != null) begin
          check(copied[iter] == iter.id * 10, "copied lookup by traversed key");
          case (iter.id)
            7: seen7 = 1;
            8: seen8 = 1;
            9: seen9 = 1;
            default: check(0, "copied traversal returned an unknown key");
          endcase
        end
        count = count + 1;
        if (step < 2)
          check(copied.next(iter), "copied next key");
      end
      check(!copied.next(iter), "copied traversal terminates");
    end
    check(count == 3, "copied traversal count after source destruction");
    check(seen7 && seen8 && seen9, "copied traversal preserves key identities");

    if (failures == 0)
      $display("PASSED");
    else
      $display("FAILED");
  end
endmodule
