module issue2033_constraint_oob;
  class relational_read;
    rand bit s;
    rand bit v[$];
    constraint c { v.size() == 0; v[0] <= s; }
  endclass

  class equality_read;
    rand bit s;
    rand bit v[$];
    constraint c { v.size() == 0; v[0] == s; }
  endclass

  class guarded_read;
    bit enabled = 0;
    rand bit v[$];
    constraint c { v.size() == 0; if (enabled) v[0] <= 1; }
  endclass

  initial begin
    relational_read relational;
    equality_read equality;
    guarded_read guarded;

    relational = new;
    equality = new;
    guarded = new;

    if (relational.randomize())
      $fatal(1, "unguarded relational out-of-range read succeeded");
    if (equality.randomize())
      $fatal(1, "unguarded equality out-of-range read succeeded");
    if (!guarded.randomize())
      $fatal(1, "false constraint guard did not eliminate the read");

    $display("PASS: out-of-range reads fail unless guarded out");
  end
endmodule
