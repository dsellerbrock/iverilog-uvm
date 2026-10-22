module p07_10_4_assignment;
  int q[$];
  int e, pos;

  initial begin
    q = '{2, 4, 8};
    q = {q, 6};
    if (q.size() != 4 || q[0] != 2 || q[1] != 4 || q[2] != 8 || q[3] != 6)
      $fatal(1, "append assignment: size=%0d", q.size());

    e = 0;
    q = {e, q};
    if (q.size() != 5 || q[0] != 0 || q[1] != 2 || q[2] != 4 || q[3] != 8 || q[4] != 6)
      $fatal(1, "prepend assignment: size=%0d", q.size());

    q = q[1:$];
    if (q.size() != 4 || q[0] != 2 || q[1] != 4 || q[2] != 8 || q[3] != 6)
      $fatal(1, "front removal assignment: size=%0d", q.size());

    q = q[0:$-1];
    if (q.size() != 3 || q[0] != 2 || q[1] != 4 || q[2] != 8)
      $fatal(1, "back removal assignment: size=%0d", q.size());

    pos = 1;
    e = 5;
    q = {q[0:pos-1], e, q[pos:$]};
    if (q.size() != 4 || q[0] != 2 || q[1] != 5 || q[2] != 4 || q[3] != 8)
      $fatal(1, "insert-before assignment: size=%0d", q.size());

    e = 7;
    q = {q[0:pos], e, q[pos+1:$]};
    if (q.size() != 5 || q[0] != 2 || q[1] != 5 || q[2] != 7 || q[3] != 4 || q[4] != 8)
      $fatal(1, "insert-after assignment: size=%0d", q.size());

    q = {};
    if (q.size() != 0)
      $fatal(1, "empty assignment: size=%0d", q.size());

    q = '{2, 4, 8};
    q = q[2:$];
    if (q.size() != 1 || q[0] != 8)
      $fatal(1, "remove-first-two assignment: size=%0d", q.size());

    q = '{2, 4, 8};
    q = q[1:$-1];
    if (q.size() != 1 || q[0] != 4)
      $fatal(1, "remove-first-and-last assignment: size=%0d", q.size());

    $display("PASS");
  end
endmodule
