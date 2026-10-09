// Exhaustive 4-state check of the vvp vector logic functors (narrow, one-word
// and multi-word widths) against their per-bit truth tables. Gold output
// was produced by the bit-serial implementation.
module top;
  reg [1:0] a, b, c, d;
  wire [1:0] w_and = a & b, w_or = a | b, w_xor = a ^ b, w_xnor = a ~^ b;
  wire [1:0] w_nand = ~(a & b), w_nor = ~(a | b), w_sum = a + b;
  wire [1:0] g_and, g_or, g_xor, g_nand, g_nor, g_xnor;
  and  ga[1:0] (g_and, a, b, c, d);
  or   go[1:0] (g_or, a, b, c);
  xor  gx[1:0] (g_xor, a, b, c, d);
  nand gna[1:0] (g_nand, a, b, c);
  nor  gno[1:0] (g_nor, a, b, c, d);
  xnor gxn[1:0] (g_xnor, a, b);
  reg [69:0] wa, wb;
  wire [69:0] ww_and = wa & wb, ww_or = wa | wb, ww_xor = wa ^ wb, ww_sum = wa + wb;
  wire [69:0] ww_n = ~(wa ^ wb);
  reg [63:0] qa, qb; wire [63:0] q_sum = qa + qb, q_and = qa & qb;
  wire [5:0] m_sum = a + wa[3:0];   // mixed widths: padded path
  integer i, j, k;
  reg [1:0] v [0:15];
  initial begin
    v[0]=2'b00; v[1]=2'b01; v[2]=2'b0x; v[3]=2'b0z; v[4]=2'b10; v[5]=2'b11; v[6]=2'b1x; v[7]=2'b1z;
    v[8]=2'bx0; v[9]=2'bx1; v[10]=2'bxx; v[11]=2'bxz; v[12]=2'bz0; v[13]=2'bz1; v[14]=2'bzx; v[15]=2'bzz;
    for (i=0;i<16;i=i+1) for (j=0;j<16;j=j+1) for (k=0;k<16;k=k+4) begin
      a=v[i]; b=v[j]; c=v[k]; d=v[(k+i)%16];
      wa = {35{v[i]}}; wb = {35{v[j]}}; wa[69] = v[k][0]; qa = {32{v[i]}}; qb={32{v[j]}};
      #1 $display("%b %b %b %b | %b %b %b %b %b %b %b | %b %b %b %b %b %b | %b %b %b %b %b | %b %b %b",
        a,b,c,d, w_and,w_or,w_xor,w_xnor,w_nand,w_nor,w_sum, g_and,g_or,g_xor,g_nand,g_nor,g_xnor,
        ww_and,ww_or,ww_xor,ww_sum,ww_n, q_sum, q_and, m_sum);
    end
    // 2-state carries across words
    wa = {70{1'b1}}; wb = 70'd1; qa = {64{1'b1}}; qb = 64'd3;
    #1 $display("%b %b", ww_sum, q_sum);
    wa = 70'h3f_ffff_ffff_ffff_fff0; wb = 70'h0_0000_0000_0000_0011;
    #1 $display("%h", ww_sum);
  end
endmodule
