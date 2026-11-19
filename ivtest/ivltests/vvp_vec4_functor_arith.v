// Exhaustive 4-state check of the vvp vector arith functors (narrow, one-word
// and multi-word widths) against procedural expressions and a per-bit
// shift reference.
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

  function [69:0] shift_ref;
    input [69:0] value;
    input [7:0] distance;
    input integer width;
    input right_shift, sign_fill;
    integer bit_index, source_index;
    reg unknown;
    begin
      shift_ref = 0;
      unknown = (^distance === 1'bx) || (sign_fill && (^value === 1'bx));
      for (bit_index = 0; bit_index < width; bit_index = bit_index + 1) begin
        source_index = right_shift ? bit_index + distance : bit_index - distance;
        if (unknown)
          shift_ref[bit_index] = 1'bx;
        else if (source_index >= 0 && source_index < width)
          shift_ref[bit_index] = value[source_index];
        else if (sign_fill)
          shift_ref[bit_index] = value[width-1];
      end
    end
  endfunction

  task check;
    input [31:0] field;
    input [69:0] actual, expected;
    begin
      if (actual !== expected) begin
        $display("Stimulus: a=%b b=%b sh=%b wa=%b wb=%b wsh=%b qa=%b qb=%b",
                 a, b, sh, wa, wb, wsh, qa, qb);
        $fatal(1, "%0s mismatch at i=%0d j=%0d k=%0d: got %b expected %b",
               field, i, j, k, actual, expected);
      end
    end
  endtask

  task check_outputs;
    reg [3:0] d_ref;
    reg [7:0] md_ref;
    reg [63:0] qd_ref;
    begin
      d_ref = a - b;
      md_ref = a - wsh;
      qd_ref = qa - qb;
      check("d", d, d_ref);
      check("e", e, a == b);
      check("ne", ne, a != b);
      check("ee", ee, a === b);
      check("nee", nee, a !== b);
      check("sl", sl, shift_ref(a, sh, 4, 0, 0));
      check("sr", sr, shift_ref(a, sh, 4, 1, 0));
      check("asr", $unsigned(asr), shift_ref(a, sh, 4, 1, 1));
      check("sl2", sl2, shift_ref(a, b, 4, 0, 0));
      check("sr2", sr2, shift_ref(a, b, 4, 1, 0));
      check("wd", wd, wa - wb);
      check("wsl", wsl, shift_ref(wa, wsh, 70, 0, 0));
      check("wsr", wsr, shift_ref(wa, wsh, 70, 1, 0));
      check("wasr", wasr, shift_ref(wa, wsh, 70, 1, 1));
      check("we", we, wa == wb);
      check("wee", wee, wa === wb);
      check("qd", qd, qd_ref);
      check("qe", qe, qa == qb);
      check("md", md, md_ref);
    end
  endtask

  initial begin
    v[0]=2'b00; v[1]=2'b01; v[2]=2'b0x; v[3]=2'b0z; v[4]=2'b10; v[5]=2'b11; v[6]=2'b1x; v[7]=2'b1z;
    v[8]=2'bx0; v[9]=2'bx1; v[10]=2'bxx; v[11]=2'bxz; v[12]=2'bz0; v[13]=2'bz1; v[14]=2'bzx; v[15]=2'bzz;
    for (i=0;i<16;i=i+1) for (j=0;j<16;j=j+1) for (k=0;k<9;k=k+1) begin
      a = {v[i], v[(i+j)%16]}; b = {v[j], v[(i*3+k)%16]};
      sh = (k==8) ? 7'bx : (k==7 ? 7'd100 : k);
      wa = {35{v[i]}}; wb = {35{v[j]}}; wa[69:66] = k; wsh = (k==8) ? 8'bz : k*9;
      qa = {32{v[i]}}; qb = {32{v[j]}};
      if (k == 5) begin wb = wa; qb = qa; end
      #1 check_outputs;
    end
    $display("PASSED");
  end
endmodule
