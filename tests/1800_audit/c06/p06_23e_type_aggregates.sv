module p06_23e;
  int pass=0, fail=0;
  task automatic ck(input string s, input bit c); if(c) pass++; else begin fail++; $display("FAIL %s",s); end endtask
  typedef struct packed {int A; int B;} AB_t; typedef struct packed {int A; int B;} otherAB_t;
  AB_t ab1,ab2; otherAB_t ab3;
  struct packed {int A; int B;} an1,an2; struct packed {int A; int B;} an3;
  typedef byte MEM_BYTES[256]; typedef bit signed [7:0] MY_MEM_BYTES[256];
  typedef logic [1:0][3:0] NIBBLES; typedef logic [7:0] MY_BYTE;
  initial begin
    ck("same_anon", type(an1)==type(an2));
    ck("other_anon", type(an1)!=type(an3));
    ck("same_typedef", type(ab1)==type(ab2));
    ck("other_typedef", type(ab3)!=type(ab1));
    ck("array_match", type(MEM_BYTES)==type(MY_MEM_BYTES));
    ck("array_mismatch", type(NIBBLES)!=type(MY_BYTE));
    $display("RESULT pass=%0d fail=%0d",pass,fail);
  end
endmodule
