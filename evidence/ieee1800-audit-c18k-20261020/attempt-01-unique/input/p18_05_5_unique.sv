// IEEE 1800-2017 §18.5.5; IEEE 1800-2023 §18.5.4.
module p18_05_5_unique;
  class U1;
    rand byte a[5];
    rand byte b;
    rand byte excluded;
    constraint u { unique {b, a[2:3], excluded}; }
    constraint exclusion { excluded == 5; }
  endclass
  class U2;
    rand bit [1:0] q[4];
    constraint c { unique {q}; }
  endclass
  class U3;
    rand bit [1:0] q[5];
    constraint c { unique {q}; }
  endclass
  class U4;
    rand bit [1:0] s;
    constraint c { unique {s}; s == 1; }
  endclass
  class U5;
    rand bit [2:0] d[];
    constraint c { d.size() == 8; unique {d}; }
  endclass

  initial begin
    U1 u1;
    U2 u2;
    U3 u3;
    U4 u4;
    U5 u5;
    int bad1, rc1, bad2, perms, bad5, rc;
    int k, seen;
    bit seenp[256];

    u1 = new;
    u2 = new;
    u3 = new;
    u4 = new;
    u5 = new;
    bad1 = 0;
    rc1 = 0;
    bad2 = 0;
    perms = 0;
    bad5 = 0;

    repeat (500) begin
      rc1 += u1.randomize();
      if (u1.excluded != 5 || u1.b == 5 || u1.a[2] == 5 || u1.a[3] == 5 ||
          u1.b == u1.a[2] || u1.b == u1.a[3] || u1.a[2] == u1.a[3]) bad1++;
    end
    $display("U1 rc_ok=%0d bad=%0d", rc1, bad1);

    repeat (200) begin
      void'(u2.randomize());
      if (u2.q[0] == u2.q[1] || u2.q[0] == u2.q[2] || u2.q[0] == u2.q[3] ||
          u2.q[1] == u2.q[2] || u2.q[1] == u2.q[3] || u2.q[2] == u2.q[3]) bad2++;
      k = {u2.q[0], u2.q[1], u2.q[2], u2.q[3]};
      if (!seenp[k]) begin seenp[k] = 1; perms++; end
    end
    $display("U2 bad=%0d distinct_perms=%0d", bad2, perms);

    rc = u3.randomize();
    $display("U3 rc=%0d", rc);
    rc = u4.randomize();
    $display("U4 rc=%0d s=%0d", rc, u4.s);

    repeat (50) begin
      seen = 0;
      void'(u5.randomize());
      foreach (u5.d[i]) seen |= (1 << u5.d[i]);
      if (u5.d.size() != 8 || seen != 8'hFF) bad5++;
    end
    $display("U5 bad=%0d", bad5);
  end
endmodule
