// IEEE 1800-2023 13.5.2: an event control on a ref formal bound to an
// unpacked-struct member or a class property waits on that member. The
// member's storage belongs to the struct variable, so a whole struct
// assignment that changes the member is seen through the ref too.
module issue2993_ref_member_event;
  typedef struct { int a; int b; real r; logic [7:0] v; } s_t;
  class C; int p; endclass

  s_t st, s2, s3;
  C o;
  int t_b = -1, t_r = -1, t_p = -1, t_d = -1, t_v = -1, t_q = -1;
  int n_w = 0, w_seen[$], t_direct = -1;

  task automatic wb(ref int x); @(x); t_b = $time; endtask
  task automatic wr(ref real x); @(x); t_r = $time; endtask
  task automatic wp(ref int x); @(x); t_p = $time; endtask
  task automatic wv(ref logic [7:0] x); @(x); t_v = $time; endtask
  // A ref formal passed on to another ref formal keeps the member binding.
  task automatic wd(ref int x); wp2(x); endtask
  task automatic wp2(ref int y); @(y); t_d = $time; endtask
  // Follows a member across whole struct assignments and NBAs.
  task automatic ww(ref int x);
    forever begin @(x); n_w++; w_seen.push_back(x); end
  endtask
  task automatic wq(ref int x); @(x); t_q = $time; endtask
  task automatic write_through(ref int x); #20 x = 11; endtask

  initial begin
    o = new;
    s2.a = 0; s2.b = 9; s3 = s2; s3.a = 5;
    fork
      wb(st.b);
      wr(st.r);
      wp(o.p);
      wv(st.v);
      wd(st.a);
      ww(s2.a);
      write_through(st.a);
    join_none
    #1 st.b = 0;     // same value: no wake
    #1 st.b = 4;     // t_b = 2
    #1 st.r = 2.5;   // t_r = 3
    #1 o.p <= 7;     // t_p = 4 (nonblocking class property)
    #1 st.a = 1;     // t_d = 5
    #1 st.v[3] = 1;  // t_v = 6 (part select)
    #1 s2 = s3;      // 7: s2.a 0 -> 5, whole assignment
    #1 s2 = s3;      // 8: unchanged, no wake
    #1 s2.a <= 6;    // 9: nonblocking member
    fork wq(st.b); join_none
    #1 st = s2;      // 10: st.b 4 -> 9 through a whole assignment
    fork begin @(st.a) t_direct = $time; end join_none
    #15;             // 20: write_through sets st.a = 11
    $display("b=%0d r=%0d p=%0d d=%0d v=%0d q=%0d direct=%0d st.a=%0d",
             t_b, t_r, t_p, t_d, t_v, t_q, t_direct, st.a);
    $display("n_w=%0d seen=%p", n_w, w_seen);
    if (t_b === 2 && t_r === 3 && t_p === 4 && t_d === 5 && t_v === 6
        && t_q === 10 && t_direct === 20 && st.a === 11
        && n_w === 2 && w_seen.size() == 2 && w_seen[0] == 5 && w_seen[1] == 6)
      $display("PASSED");
    else
      $display("FAILED");
  end
endmodule
