// Exhaustive 4-state check of the vvp vector arith functors (narrow, one-word
// and multi-word widths) against their per-bit truth tables. Gold output
// was produced by the bit-serial implementation.
module top;
  reg [3:0] a, b; reg [6:0] sh;
  wire [3:0] d = a - b;
  wire e = (a == b), ne = (a != b), ee = (a === b), nee = (a !== b);
  wire [3:0] sl = a << sh, sr = a >> sh;
  wire signed [3:0] sa = a;
  wire signed [3:0] asr = sa >>> sh;
  wire [3:0] sl2 = a << b, sr2 = a >> b;
  reg [69:0] wa, wb; reg [7:0] wsh;
  wire [69:0] wd = wa - wb, wsl = wa << wsh, wsr = wa >> wsh;
  wire signed [69:0] swa = wa;
  wire signed [69:0] wasr = swa >>> wsh;
  wire we = (wa == wb), wee = (wa === wb);
  reg [63:0] qa, qb; wire [63:0] qd = qa - qb; wire qe = (qa == qb);
  wire [7:0] md = a - wsh;  // mixed widths -> padded path
  integer i, j, k;
  reg [1:0] v [0:15];
  initial begin
    v[0]=2'b00; v[1]=2'b01; v[2]=2'b0x; v[3]=2'b0z; v[4]=2'b10; v[5]=2'b11; v[6]=2'b1x; v[7]=2'b1z;
    v[8]=2'bx0; v[9]=2'bx1; v[10]=2'bxx; v[11]=2'bxz; v[12]=2'bz0; v[13]=2'bz1; v[14]=2'bzx; v[15]=2'bzz;
    for (i=0;i<16;i=i+1) for (j=0;j<16;j=j+1) for (k=0;k<9;k=k+1) begin
      a = {v[i], v[(i+j)%16]}; b = {v[j], v[(i*3+k)%16]};
      sh = (k==8) ? 7'bx : (k==7 ? 7'd100 : k);
      wa = {35{v[i]}}; wb = {35{v[j]}}; wa[69:66] = k; wsh = (k==8) ? 8'bz : k*9;
      qa = {32{v[i]}}; qb = {32{v[j]}};
      if (k == 5) begin wb = wa; qb = qa; end
      #1 $display("%b %b %b|%b %b%b%b%b|%b %b %b %b %b|%b %b %b %b %b%b|%b %b|%b",
        a,b,sh,d,e,ne,ee,nee,sl,sr,asr,sl2,sr2,wd,wsl,wsr,wasr,we,wee,qd,qe,md);
    end
  end
endmodule
