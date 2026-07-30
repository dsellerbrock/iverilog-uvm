// Indexed part-select READS on a packed-struct member vector:
// s.key[b -: w] and s.key[b +: w] with a constant base. Pre-fix
// (recovery C4-p07) the [b -: w] form crashed the compiler outright:
// calculate_part() had no SEL_IDX_DO case and hit ivl_assert(0).
// (Assignments THROUGH a member part-select remain a separate loud
// sorry and are not exercised here.)
typedef struct packed {
  logic [7:0] key;
  logic [3:0] pad;
} s_t;

module main;
  s_t s;
  logic [1:0] r;
  int fails = 0;

  initial begin
    s.key = 8'hA5;   // 1010_0101
    s.pad = 4'hF;

    // [3 -: 2] selects bits [3:2] = 2'b01
    r = s.key[3 -: 2];
    if (r !== 2'h1) begin fails++; $display("FAILED: down read %h", r); end

    // [4 +: 2] selects bits [5:4] = 2'b10
    r = s.key[4 +: 2];
    if (r !== 2'h2) begin fails++; $display("FAILED: up read %h", r); end

    // [7 -: 4] = upper nibble
    if (s.key[7 -: 4] !== 4'hA) begin fails++; $display("FAILED: nibble %h", s.key[7 -: 4]); end

    // expression context and neighbors intact
    if ({s.key[3 -: 2], s.key[1 -: 2]} !== 4'h5) begin
      fails++; $display("FAILED: concat %h", {s.key[3 -: 2], s.key[1 -: 2]});
    end
    if (s.pad !== 4'hF) begin fails++; $display("FAILED: pad %h", s.pad); end

    if (fails == 0) $display("PASSED");
    else $display("FAILED count=%0d", fails);
  end
endmodule
