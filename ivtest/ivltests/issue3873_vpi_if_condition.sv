module top;
  logic [3:0] bus = 4'b10xz;
  real level = -2.5;
  int result;

  task equality;
    if (bus == 4'b1001) result = 11;
    else result = 12;
  endtask

  task plain_if;
    if (bus) result = 21;
  endtask

  task folded_true;
    if (4'b10xz) result = 31;
    else $fatal(1, "executed unselected else arm");
  endtask

  task folded_false;
    if (4'b00xz) $fatal(1, "executed unselected then arm");
    else result = 32;
  endtask

  task empty_else;
    if (bus) result = 41;
    else ;
  endtask

  task real_if;
    if (level) result = 51;
  endtask

  task real_literal;
    if (-3.25) result = 61;
  endtask

  task immediate_assertion;
    assert (bus == 4'b1001) result = 71;
    else result = 72;
  endtask

  initial begin
    $issue3873_check;

    equality();
    if (result != 12) $fatal(1, "unknown equality took then arm");
    plain_if();
    if (result != 21) $fatal(1, "nonzero vector skipped then arm");
    folded_true();
    if (result != 31) $fatal(1, "missing folded then arm");
    folded_false();
    if (result != 32) $fatal(1, "missing folded else arm");
    empty_else();
    if (result != 41) $fatal(1, "wrong result with empty else arm");
    real_if();
    if (result != 51) $fatal(1, "nonzero real skipped then arm");
    real_literal();
    if (result != 61) $fatal(1, "nonzero real literal skipped then arm");
    immediate_assertion();
    if (result != 72) $fatal(1, "missing assertion failure action");

    bus = 4'b1001;
    equality();
    if (result != 11) $fatal(1, "true equality took else arm");
    bus = 4'b00xz;
    plain_if();
    empty_else();
    level = 0.0;
    real_if();
    if (result != 11) $fatal(1, "false predicate executed a then arm");
    $display("issue3873 PASSED");
  end
endmodule
