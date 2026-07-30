// Variable indices into packed struct/union members, through ONE
// canonical offset calculation (recovery C4 wave 2). Pre-fix, every
// shape here either crashed the compiler (lvalue variable bit index:
// ivl_assert(rc)) or was a hard "must be constant here" error.
typedef struct packed {
  logic [7:0]      key;      // single-dim vector member
  logic [3:0][7:0] mat;      // two-dim vector member
  logic [1:0]      pad;
} s_t;

typedef struct packed {
  logic [7:0] w;
} inner_s;

typedef struct packed {
  inner_s b;
  logic [3:0] t;
} nest_t;

typedef union packed {
  logic [15:0] whole;
  logic [3:0][3:0] nib;
} u_t;

typedef struct packed { logic qe; logic [2:0] fld; } e_t;

module main;
  s_t s;
  nest_t n;
  u_t u;
  e_t arr [4];         // unpacked array of packed structs (G16)
  s_t sd;
  int fails = 0;
  int i;

  // ascending-range sibling for direction parity
  typedef struct packed { logic [0:7] akey; } sa_t;
  sa_t sa;

  initial begin
    // ---- variable bit index, lvalue then rvalue (crashed pre-fix)
    for (i = 0; i < 8; i++) s.key[i] = i[0];
    for (i = 0; i < 8; i++)
      if (s.key[i] !== i[0]) begin fails++; $display("FAILED: key[%0d]=%b", i, s.key[i]); end
    if (s.key !== 8'b10101010) begin fails++; $display("FAILED: key=%b", s.key); end

    // ---- variable prefix index in a 2-dim member
    for (i = 0; i < 4; i++) s.mat[i] = 8'hA0 + i[7:0];
    for (i = 0; i < 4; i++)
      if (s.mat[i] !== (8'hA0 + i[7:0])) begin fails++; $display("FAILED: mat[%0d]=%h", i, s.mat[i]); end
    i = 2;
    s.mat[i][3] = 1'b1;
    if (s.mat[2] !== 8'hAA) begin fails++; $display("FAILED: mat2=%h", s.mat[2]); end

    // ---- variable-base indexed part-selects on a member
    s.key = 8'hA5;
    i = 3;
    if (s.key[i -: 2] !== 2'h1) begin fails++; $display("FAILED: down %h", s.key[i -: 2]); end
    i = 4;
    if (s.key[i +: 2] !== 2'h2) begin fails++; $display("FAILED: up %h", s.key[i +: 2]); end
    i = 5;
    s.key[i +: 2] = 2'b11;
    if (s.key !== 8'hE5) begin fails++; $display("FAILED: up write %h", s.key); end

    // ---- nested struct member vector, variable index
    n.b.w = 8'h00; n.t = 4'hC;
    for (i = 0; i < 8; i++) n.b.w[i] = ~i[0];
    if (n.b.w !== 8'b01010101) begin fails++; $display("FAILED: nested %b", n.b.w); end
    if (n.t !== 4'hC) begin fails++; $display("FAILED: nested sibling %h", n.t); end

    // ---- packed union member, variable index
    u.whole = 16'h4321;
    i = 2;
    if (u.nib[i] !== 4'h3) begin fails++; $display("FAILED: union %h", u.nib[i]); end
    u.nib[i] = 4'hF;
    if (u.whole !== 16'h4F21) begin fails++; $display("FAILED: union write %h", u.whole); end

    // ---- ascending-range member, variable index (direction parity)
    sa.akey = 8'h00;
    i = 0; sa.akey[i] = 1'b1;   // [0:7]: index 0 is the MSB
    if (sa.akey !== 8'h80) begin fails++; $display("FAILED: asc %h", sa.akey); end
    i = 7;
    if (sa.akey[i] !== 1'b0) begin fails++; $display("FAILED: asc read %b", sa.akey[i]); end

    // ---- unpacked array of packed structs, variable word index (G16)
    for (i = 0; i < 4; i++) begin
      arr[i].qe  = i[0];
      arr[i].fld = i[2:0];
    end
    for (i = 0; i < 4; i++) begin
      if (arr[i].qe !== i[0]) begin fails++; $display("FAILED: arr[%0d].qe=%b", i, arr[i].qe); end
      if (arr[i].fld !== i[2:0]) begin fails++; $display("FAILED: arr[%0d].fld=%h", i, arr[i].fld); end
    end

    // ---- constant shapes beside them stay put
    sd.key = 8'h5A;
    if (sd.key[7:4] !== 4'h5 || sd.key[3:0] !== 4'hA) begin
      fails++; $display("FAILED: const part %h", sd.key);
    end

    if (fails == 0) $display("PASSED");
    else $display("FAILED count=%0d", fails);
  end
endmodule
