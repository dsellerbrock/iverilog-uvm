// IEEE 1800-2017/2023 6.4, 8.4, 10.6 and 10.6.2.
module issue3648;
  class C;
    int k;
  endclass

  C target, source, other;

  initial begin
    source = new;
    source.k = 5;
    other = new;
    other.k = 9;

    force target = source;
    if (target != source || target.k != 5)
      $fatal(1, "force did not immediately install the source handle");
    target.k = 6;
    if (source.k != 6)
      $fatal(1, "forced handle did not alias the source object");

    target = other;
    if (target != source)
      $fatal(1, "a procedural store overrode the force");
    source = null;
    #1;
    if (target != null)
      $fatal(1, "force did not follow a null source");
    source = new;
    source.k = 7;
    #1;
    if (target != source || target.k != 7)
      $fatal(1, "force did not follow source reassignment");

    force target = other;
    source = null;
    #1;
    if (target != other)
      $fatal(1, "replacement force still followed the first source");

    target = null;
    release target;
    other = null;
    #1;
    if (target == null || target.k != 9)
      $fatal(1, "release did not retain the last forced handle");
    target = source;
    if (target != null)
      $fatal(1, "release did not reenable procedural stores");

    force target = null;
    target = new;
    if (target != null)
      $fatal(1, "force with a literal null RHS did not override a store");
    release target;
    if (target != null)
      $fatal(1, "release did not retain a forced null handle");
    $display("PASSED");
  end
endmodule
