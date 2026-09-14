module test;
  function automatic int assignment_ops;
    int i, j, fail;
    fail=0;
    i=10; j=(i=5); if (i!==5 || j!==5) fail|=1;
    i=10; j=(i+=3); if (i!==13 || j!==13) fail|=2;
    i=10; j=(i-=3); if (i!==7 || j!==7) fail|=4;
    i=10; j=(i*=3); if (i!==30 || j!==30) fail|=8;
    i=10; j=(i/=3); if (i!==3 || j!==3) fail|=16;
    i=10; j=(i%=3); if (i!==1 || j!==1) fail|=32;
    i=10; j=(i&=3); if (i!==2 || j!==2) fail|=64;
    i=10; j=(i|=1); if (i!==11 || j!==11) fail|=128;
    i=10; j=(i^=3); if (i!==9 || j!==9) fail|=256;
    i=10; j=(i<<=1); if (i!==20 || j!==20) fail|=512;
    i=10; j=(i>>=1); if (i!==5 || j!==5) fail|=1024;
    return fail;
  endfunction
  function automatic int incdec;
    int i, a, b, c, d;
    i=10; a=i++; b=++i; c=i--; d=--i;
    return 100000*i + 1000*a + 100*b + 10*c + d;
  endfunction
  function automatic logic [15:0] narrow_wrap;
    logic [7:0] i, j;
    i=255; j=i++; return {i,j};
  endfunction
  function automatic logic [15:0] signed_values;
    logic signed [7:0] i,j;
    i=127; j=(i+=1); i>>>=1; return {i,j};
  endfunction
  function automatic logic [255:0] wide_value;
    logic [127:0] i,j;
    i=(128'd1<<100)+5; j=i++; return {i,j};
  endfunction
  function automatic logic [7:0] bit_value;
    bit [3:0] i,j;
    j=(i=4'bx101); return {i,j};
  endfunction
  function automatic int short_circuit;
    int i=0;
    if (0 && i++) return -1;
    if (1 || i++) return i;
    return -2;
  endfunction
  function automatic real real_post;
    real i,j; i=1.5; j=i++; return 10.0*i+j;
  endfunction
  function automatic real real_pre_dec;
    real i,j; i=1.5; j=--i; return 10.0*i+j;
  endfunction
  function automatic int independent;
    int i=0, j; j=i++; return 10*i+j;
  endfunction
  function automatic logic [7:0] uninitialized_bit;
    bit [3:0] i,j; j=++i; return {i,j};
  endfunction
  function automatic logic [7:0] uninitialized_logic;
    logic [3:0] i,j; j=++i; return {i,j};
  endfunction
  function automatic real uninitialized_real;
    real i,j; j=i++; return 10.0*i+j;
  endfunction
  localparam int OPS=assignment_ops(), INC=incdec();
  localparam logic [15:0] NARROW=narrow_wrap(), SIGNED=signed_values();
  localparam logic [255:0] WIDE=wide_value();
  localparam logic [7:0] BITVAL=bit_value();
  localparam int SHORT=short_circuit();
  localparam real RPOST=real_post(), RPRE=real_pre_dec();
  localparam int FIRST=independent(), SECOND=independent();
  localparam logic [7:0] UBIT=uninitialized_bit(), ULOGIC=uninitialized_logic();
  localparam real UREAL=uninitialized_real();
  initial begin
    if (OPS!==0 || INC!==1011330 || NARROW!==16'h00ff
        || SIGNED!==16'hc080 || WIDE!=={((128'd1<<100)+6),((128'd1<<100)+5)}
        || BITVAL!==8'h55 || SHORT!==0 || RPOST!=26.5 || RPRE!=5.5
        || FIRST!==10 || SECOND!==10 || UBIT!==8'h11
        || ULOGIC!==8'hxx || UREAL!=10.0)
      $fatal(1,"effects %0d/%0d %h/%h/%h %h/%0d %f/%f",
             OPS,INC,NARROW,SIGNED,WIDE,BITVAL,SHORT,RPOST,RPRE);
    $display("PASSED");
  end
endmodule
