// IEEE 1800-2017 18.6: an object randomize() call with an inline
// constraint is legal when its return value is discarded.  This pins
// the statement lowering to the same Z3, selector, hook, and rollback
// semantics as the expression form.

module main;
  int fails = 0;
  bit [7:0] target = 8'd55;

  class item;
    rand bit [7:0] x;
    rand bit [7:0] y;
    int pre_calls;
    int post_calls;
    constraint relation { y == x + 1; }

    function void pre_randomize;
      pre_calls++;
    endfunction

    function void post_randomize;
      post_calls++;
    endfunction

    task self_sample(input bit [7:0] expected);
      this.randomize() with { x == expected; };
    endtask
  endclass

  class holder;
    item p;

    function new;
      p = new;
    endfunction

    function item get;
      return p;
    endfunction
  endclass

  item direct = new;
  item items[2];
  holder nested = new;

  task automatic sample_in_task(item p, input bit [7:0] expected);
    p.randomize() with { x == expected; };
  endtask

  task check(string label, int got, int expected);
    if (got != expected) begin
      $display("FAILED -- %s: got %0d expected %0d",
               label, got, expected);
      fails++;
    end
  endtask

  initial begin
    items[0] = new;
    items[1] = new;

    // Direct receiver and a value captured from the caller scope.
    direct.randomize() with { x == target; };
    check("direct x", direct.x, 55);
    check("direct y", direct.y, 56);

    // Nested property receiver.
    nested.p.randomize() with { x == 8'd21; };
    check("nested x", nested.p.x, 21);
    check("nested y", nested.p.y, 22);

    // Inline variable control must still preserve unlisted state.
    direct.x = 9;
    direct.y = 10;
    direct.randomize(x) with { x == 8'd9; };
    check("selector x", direct.x, 9);
    check("selector preserves y", direct.y, 10);

    // The constraint value belongs to an automatic task frame.
    sample_in_task(direct, 77);
    check("task x", direct.x, 77);
    check("task y", direct.y, 78);

    // The explicit void-cast sibling uses the same solver path without
    // the ordinary discarded-function warning.
    void'(direct.randomize() with { x == 88; });
    check("void cast x", direct.x, 88);
    check("void cast y", direct.y, 89);

    // Receiver expressions and indexed handle-array receivers.
    nested.get().randomize() with { x == 33; };
    check("call-result receiver x", nested.p.x, 33);
    check("call-result receiver y", nested.p.y, 34);

    items[1].randomize() with { x == target + 11; };
    check("indexed receiver x", items[1].x, 66);
    check("indexed receiver y", items[1].y, 67);

    // Parentheses are optional on a no-argument method call.
    direct.randomize with { x == 44; };
    check("no parentheses x", direct.x, 44);
    check("no parentheses y", direct.y, 45);

    // An unqualified in-class call resolves through the current object.
    direct.self_sample(66);
    check("implicit receiver x", direct.x, 66);
    check("implicit receiver y", direct.y, 67);

    // A failed statement call must roll back the object, run
    // pre_randomize, and skip post_randomize.
    direct.x = 31;
    direct.y = 32;
    begin
      int pre_before;
      int post_before;
      pre_before = direct.pre_calls;
      post_before = direct.post_calls;
      direct.randomize() with { x == 1; x == 2; };
      check("failed call preserves x", direct.x, 31);
      check("failed call preserves y", direct.y, 32);
      check("failed call ran pre_randomize", direct.pre_calls,
            pre_before + 1);
      check("failed call skipped post_randomize", direct.post_calls,
            post_before);
    end

    if (fails == 0) $display("PASSED");
    $finish(0);
  end
endmodule
