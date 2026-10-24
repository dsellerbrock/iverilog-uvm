module p06_19a_enum_decl;
  int pass = 0, fail = 0;
  task automatic ck(input string id, input bit c);
    if (c) pass++;
    else begin fail++; $display("FAIL %s", id); end
  endtask

  enum {red, yellow, green} l1;
  enum {bronze=3, silver, gold} medal;
  enum {a=3, b=7, c} alpha;
  enum {a2, b2=7, c2} alpha2;
  typedef enum {add=10, sub[5], jmp[6:8]} E1;
  enum {register[2]=1, register[2:4]=10} vr;
  enum integer {IDLE=0, XX='x, S1='b01, S2='b10} st4;
  enum bit [3:0] {bronze2='h3, silver2, gold2='h5} m2;
  enum bit [3:0] {bronze3=4'h3, silver3, gold3=4'h5} m3;
  typedef enum {NO, YES} boolean;
  boolean myvar;

  initial begin
    ck("anon_int", $bits(l1) == 32 && red == 0 && yellow == 1 && green == 2);
    ck("auto_inc", bronze == 3 && silver == 4 && gold == 5);
    ck("auto_inc2", a == 3 && b == 7 && c == 8);
    ck("first_zero", a2 == 0 && b2 == 7 && c2 == 8);
    ck("range_N", add == 10 && sub0 == 11 && sub1 == 12 && sub4 == 15 && jmp6 == 16 && jmp7 == 17 && jmp8 == 18);
    ck("range_reg", register0 == 1 && register1 == 2 && register2 == 10 && register3 == 11 && register4 == 12);
    $display("INFO enum_values IDLE=%b XX=%b S1=%b S2=%b", IDLE, XX, S1, S2);
    ck("integer_xz", XX === 32'bx);
    ck("integer_s1", S1 == 1);
    ck("integer_s2", S2 == 2);
    ck("integer_idle", IDLE == 0);
    ck("bit4", $bits(m2) == 4 && bronze2 == 3 && silver2 == 4 && gold2 == 5 && gold3 == 5);
    myvar = YES;
    ck("typedef", myvar == YES && myvar != NO);
    ck("default_int_enum", l1 == red);
    ck("default_4state_x", st4 === 32'bx);
    $display("RESULT pass=%0d fail=%0d", pass, fail);
  end
endmodule
