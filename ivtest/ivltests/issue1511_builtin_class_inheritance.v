// IEEE 1800-2017/2023 15.2: built-in semaphore/mailbox classes may be bases.
class mysem extends semaphore;
  int marker;
  function new(int count = 0);
    super.new(count);
    marker = 41;
  endfunction
  function int marker_value();
    return marker;
  endfunction
endclass

class mymb extends mailbox #(int);
  int marker;
  function new(int bound = 0);
    super.new(bound);
    marker = 42;
  endfunction
  function int marker_value();
    return marker;
  endfunction
endclass

module tb;
  mysem s;
  semaphore sb;
  mymb m;
  mailbox #(int) mb;
  int got;

  initial begin
    s = new(2);
    if (s.marker_value() != 41 || !s.try_get(2) || s.try_get())
      $fatal(1, "derived semaphore behavior or constructor state failed");
    s.put(2);
    sb = s;
    if (!sb.try_get(1))
      $fatal(1, "semaphore base handle lost inherited state");
    s.put(1);
    if (!s.try_get(2))
      $fatal(1, "semaphore base handle did not share resource state");
    sb.put(2);
    s.get(2);
    if (s.try_get())
      $fatal(1, "inherited semaphore get did not update shared state");

    m = new(1);
    if (m.marker_value() != 42 || !m.try_put(17) || m.try_put(99)
        || m.num() != 1)
      $fatal(1, "derived mailbox behavior or constructor state failed");
    if (m.try_peek(got) != 1 || got != 17 || m.num() != 1)
      $fatal(1, "inherited typed mailbox try_peek failed");
    mb = m;
    mb.get(got);
    if (got != 17 || m.num() != 0)
      $fatal(1, "mailbox base handle lost inherited state");
    mb.put(23);
    if (m.try_get(got) != 1 || got != 23 || m.num() != 0)
      $fatal(1, "mailbox derived handle did not share resource state");

    $display("ISSUE1511 PASS");
    $display("PASSED");
  end
endmodule
