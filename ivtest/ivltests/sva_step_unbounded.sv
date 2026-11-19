`timescale 1ns/1ns
module top;
  bit [4:0] clk;
  bit a, za, ia, ic, ca, dis, sa, sb;
  logic b, zb, ib, cb;
  int p, f, zp, zf, ip, cp, sp;

  linear: assert property (@(posedge clk[0]) a ##[1:$] b) p++; else f++;
  zero_wait: assume property (@(posedge clk[1]) za ##[0:$] zb) zp++; else zf++;
  delayed: assert property (@(posedge clk[2]) ia ##1 ic |=> ##[1:$] ib) ip++;
  cancel: assert property (@(posedge clk[3]) disable iff (dis) ca ##[1:$] cb)
    cp++; else ;
  stress: assert property (@(posedge clk[4]) sa ##[1:$] sb) sp++; else ;

  task tick(input int which);
    #5 clk[which] = 1;
    #5 clk[which] = 0;
  endtask

  initial begin
    #1 $wait_setup;
    a = 1; b = 0; tick(0);        // 6, enabled start
    b = 1'bx; tick(0);           // 16, unarmed start
    b = 1'bz; tick(0);           // 26, enabled start
    a = 0; b = 0;
    tick(0);                    // 36, two enabled waiters and no new start
    b = 1; tick(0);              // 46, all three obligations accept
    $wait_on;
    tick(0);                    // 56, failing prefix of a fresh attempt
    if (p != 3 || f != 1) $fatal(1, "linear actions %0d %0d", p, f);

    za = 1; zb = 1; tick(1);      // 66, both guards match in one step
    zb = 1'bx; tick(1);          // 76, prefix matches and starts waiting
    za = 0; zb = 1; tick(1);      // 86, old attempt accepts, new one fails
    if (zp != 2 || zf != 1) $fatal(1, "zero actions %0d %0d", zp, zf);

    ia = 1; ib = 1; tick(2);      // 96, first antecedent guard
    ia = 0; ic = 1; tick(2);      // 106, match for 96, vacuity for 106
    tick(2);                    // 116, final guard is true but ineligible
    if (ip != 2) $fatal(1, "early delayed acceptance");
    ib = 0; tick(2);              // 126, first eligible tick misses
    ib = 1; tick(2);              // 136, accepts
    if (ip != 5) $fatal(1, "delayed actions %0d", ip);

    ca = 1; cb = 0; tick(3);      // 146
    tick(3);                    // 156
    ca = 0; tick(3);              // 166, both are mature
    #1 dis = 1;
    #1 dis = 0;
    cb = 1; tick(3);              // 178, pulse discarded both waiters
    ca = 1; cb = 0; tick(3);      // 188
    tick(3);                    // 198
    ca = 0; tick(3);              // 208, both are mature
    tick(3);                    // 218, first waiter callback kills both
    ca = 1; cb = 1; tick(3);      // 228, new start after re-enable
    ca = 0; tick(3);              // 238, only the new attempt accepts
    if (cp != 1) $fatal(1, "cancellation actions %0d", cp);

    // The early arming and callback times cross the 32-bit time boundary.
    #4294967040;
    $wait_stress_arm;
    sa = 1;
    repeat (2) tick(4);
    $wait_stress_watch;           // first attempt already entered the wait
    repeat (21) tick(4);          // 20 enabled starts, 3 unenabled starts
    sa = 0;
    repeat (276) tick(4);
    if (sp != 0) $fatal(1, "early stress acceptance");
    sb = 1; tick(4);              // all 23 attempts accept at clock index 299
    sb = 0; tick(4);
    if (sp != 23) $fatal(1, "stress actions %0d", sp);
    $wait_stress_check;
    $display("PASSED");
    $finish(0);
  end
endmodule
