// IEEE 1800-2017 18.7.1: local:: selects the caller-scope value in an
// inline constraint. Parentheses on a no-argument size call do not change
// that selection, even when the target object has a colliding property.
module main;
  class size_item;
    rand int unsigned data[];
    constraint target_size_c { data.size == 1; }
  endclass

  int unsigned data[];
  int errors = 0;

  task automatic check(input string label, input bit ok);
    if (!ok) begin
      $display("FAILED -- %0s", label);
      errors++;
    end
  endtask

  initial begin
    automatic size_item item = new;
    automatic int ok;

    data = new[2];

    ok = item.randomize() with { local::data.size == 2; };
    check("paren-less caller size", ok && item.data.size() == 1);

    ok = item.randomize() with { local::data.size() == 2; };
    check("parenthesized caller size", ok && item.data.size() == 1);

    ok = item.randomize() with {
      local::data.size == 2;
      local::data.size() == 2;
    };
    check("caller size spellings agree", ok && item.data.size() == 1);

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED -- %0d errors", errors);
  end
endmodule
