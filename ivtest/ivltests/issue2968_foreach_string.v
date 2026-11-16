// IEEE 1800-2023 18.5.7.1: in a foreach iterative constraint a string
// variable is treated as a dynamic array of bytes indexed from 0 to N-1.
class item;
  string s = "ab";
  rand bit [1:0] x;
  rand byte ch;
  constraint c_index { foreach (s[i]) x != i; }
  constraint c_char  { foreach (s[i]) ch != s[i]; }
endclass

module issue2968_foreach_string;
  item o;
  int ok = 1;

  task automatic check(bit cond, string what);
    if (!cond) begin
      $display("FAILED: %s", what);
      ok = 0;
    end
  endtask

  initial begin
    o = new;
    check(o.randomize() with { x == 2; }, "index 2 is legal for \"ab\"");
    check(!o.randomize() with { x == 1; }, "index 1 is excluded for \"ab\"");
    check(!o.randomize() with { ch == "b"; }, "character b is excluded");
    check(o.randomize() with { ch == "c"; }, "character c is legal");
    // The length and characters are read at each randomize() call.
    o.s = "abcd";
    check(!o.randomize() with { x == 3; }, "index 3 is excluded for \"abcd\"");
    check(!o.randomize() with { ch == "d"; }, "character d is excluded");
    o.s = "";
    check(o.randomize() with { x == 0; ch == "a"; }, "empty string adds nothing");
    o.s = "xyz";
    repeat (20) begin
      check(o.randomize(), "randomize succeeds");
      check(o.x == 3, "only index 3 remains");
      check(o.ch != "x" && o.ch != "y" && o.ch != "z", "characters excluded");
    end
    if (ok) $display("PASSED");
  end
endmodule
