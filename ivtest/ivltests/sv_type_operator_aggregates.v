// IEEE 1800-2017/2023 6.22.1 and 6.23: nominal aggregate and array matching.
module test;
  bit failed = 0;

  struct { int A; int B; } an1, an2;
  struct { int A; int B; } an3;
  union { int I; bit [31:0] B; } un1, un2;
  union { int I; bit [31:0] B; } un3;

  typedef struct { int A; int B; } AB_t;
  AB_t ab1, ab2;
  typedef struct { int A; int B; } otherAB_t;
  otherAB_t ab3;

  typedef byte MEM_BYTES [256];
  typedef bit signed [7:0] MY_MEM_BYTES [256];
  MEM_BYTES mem_bytes;
  MY_MEM_BYTES my_mem_bytes;

  typedef byte DESCENDING [7:0];
  DESCENDING descending;

  initial begin
    if (type(an1) != type(an2)) failed = 1;
    if (type(an1) == type(an3)) failed = 1;
    if (type(un1) != type(un2)) failed = 1;
    if (type(un1) == type(un3)) failed = 1;
    if (type(ab1) != type(ab2)) failed = 1;
    if (type(ab3) == type(ab1)) failed = 1;
    if (type(mem_bytes) != type(my_mem_bytes)) failed = 1;
    if (type(mem_bytes) == type(descending)) failed = 1;

    if (failed) $display("FAILED");
    else $display("PASSED");
  end
endmodule
