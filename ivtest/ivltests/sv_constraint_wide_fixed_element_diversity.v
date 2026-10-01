class leaf; rand bit [127:0] value[1]; endclass
class item;
  rand leaf child;
  constraint touch { child.value[0] == child.value[0]; }
  function new; child = new; endfunction
endclass
module test;
  initial begin
    item a, replay, other;
    bit [127:0] high_or;
    bit differs;
    a = new; replay = new; other = new;
    a.srandom(32'h1234); replay.srandom(32'h1234); other.srandom(32'h5678);
    repeat (4) begin
      if (!a.randomize() || !replay.randomize() || !other.randomize())
        $fatal(1, "unconstrained wide randomize failed");
      if (a.child.value[0] !== replay.child.value[0])
        $fatal(1, "same-seed wide replay mismatch");
      high_or |= a.child.value[0];
      differs |= a.child.value[0] !== other.child.value[0];
    end
    if (high_or[127:64] == 0 || !differs)
      $fatal(1, "wide random target lost high-bit diversity");
    $display("PASSED");
  end
endmodule
