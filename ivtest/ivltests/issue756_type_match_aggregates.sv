// IEEE 1800-2017/2023 6.22.1 matching types through the 6.23 type()
// operator: (c) an anonymous struct/union matches only the objects of its
// own declaration statement, (d) a typedef matches itself, and (f) arrays
// match when they are the same kind with the same bounds (and index type)
// and matching element types.
module issue756_type_match_aggregates;
  typedef struct packed {int A; int B;} AB_t;
  typedef struct packed {int A; int B;} otherAB_t;
  typedef AB_t AB_alias_t;
  typedef union packed {int i; bit [31:0] u;} U_t;
  typedef struct {int x; string s;} unpk_t;
  AB_t ab1, ab2;
  otherAB_t ab3;
  AB_alias_t ab4;
  struct packed {int A; int B;} an1, an2;
  struct packed {int A; int B;} an3;
  U_t u1, u2;
  unpk_t us1, us2;
  typedef byte MEM_BYTES[256];
  typedef bit signed [7:0] MY_MEM_BYTES[256];
  int fa[4], fb[4], fc[0:3], fd[3:0], fe[5];
  shortint ff[4];
  int da[], db[];
  int qa[$], qb[$], qc[$:4];
  int aa[string], ab[string], ac[int];
  AB_t sq1[$], sq2[$];
  otherAB_t sq3[$];
  bit failed = 0;

  `define check(expr, val) \
    if ((expr) !== (val)) begin $display("FAILED: %s", `"expr`"); failed = 1; end

  initial begin
    `check(type(ab1) == type(ab2), 1)
    `check(type(ab1) == type(AB_t), 1)
    `check(type(ab4) == type(ab1), 1)
    `check(type(ab1) != type(ab3), 1)
    `check(type(an1) == type(an2), 1)
    `check(type(an1) != type(an3), 1)
    `check(type(an1) != type(ab1), 1)
    `check(type(u1) == type(u2), 1)
    `check(type(u1) != type(ab1), 1)
    `check(type(us1) === type(us2), 1)
    `check(type(MEM_BYTES) == type(MY_MEM_BYTES), 1)
    `check(type(fa) == type(fb), 1)
    `check(type(fa) == type(fc), 1)        // [4] is [0:3]
    `check(type(fc) != type(fd), 1)        // different left/right bounds
    `check(type(fa) != type(fe), 1)
    `check(type(fa) != type(ff), 1)        // element types differ
    `check(type(da) == type(db), 1)
    `check(type(da) != type(qa), 1)        // dynamic array vs queue
    `check(type(qa) == type(qb), 1)
    `check(type(qa) != type(qc), 1)
    `check(type(aa) == type(ab), 1)
    `check(type(aa) != type(ac), 1)        // index types differ
    `check(type(aa) != type(qa), 1)
    `check(type(sq1) == type(sq2), 1)
    `check(type(sq1) !== type(sq3), 1)
    if (!failed) $display("PASSED");
  end
endmodule
