// Partial-index unpacked subarrays are aggregate values (IEEE 1800-2017
// 7.6), not the first scalar word of the selected row. Exercise procedural
// reads, procedural writes, continuous l-values, declared-direction mapping,
// nonblocking scheduling, and always_comb sensitivity on the original source.
module sv_uarray_partial_index_copy;
  localparam int ROW = 2;
  localparam logic [7:0] XZ_VALUE = 8'b10xz_01zx;

  typedef enum logic [1:0] {E0, E1, E2, E3} e_t;
  typedef struct packed {
    logic [3:0] hi;
    logic [3:0] lo;
  } pair_t;

  class holder_t;
    logic [7:0] words [3:1];
  endclass

  logic [7:0] src [3:2][3:1];
  logic [7:0] dst [5:7];
  logic [7:0] dst_slice [1:0][5:7];

  logic [7:0] src3 [4:3][7:6][2:4];
  logic [7:0] dst3 [2:4];

  logic [7:0] whole_src [3:1];
  logic [7:0] whole_dst [5:7];
  logic [7:0] whole_q [5:7];
  logic [7:0] whole_to_slice [1:0][5:7];
  logic [7:0] whole_to_slice_q [1:0][5:7];
  logic [7:0] prop_dst [5:7];
  holder_t holder;

  e_t enum_src [1:0][3:1];
  e_t enum_dst [5:7];
  pair_t struct_src [1:0][3:1];
  pair_t struct_dst [5:7];

  logic [7:0] storage_desc [1:0];
  logic [7:0] other_asc [0:1];
  logic [7:0] datapath [2:0][0:1];

  logic [7:0] single [1];
  logic [7:0] datapath1 [1:0][1];

  logic clk = 0;
  logic [7:0] q [5:7];
  logic [7:0] q_slice [1:0][5:7];
  int errors = 0;

  always_comb begin
    // The residual source range is descending while both destinations are
    // ascending. Assignment maps declared left to declared left.
    dst = src[ROW];
    dst_slice[1] = src[ROW];

    // Two constant prefix indices into a three-dimensional source.
    dst3 = src3[4][6];
  end

  always_ff @(posedge clk) begin
    q <= src[ROW];
    q_slice[1] <= src[ROW];
    whole_q <= whole_src;
    whole_to_slice_q[1] <= whole_src;
  end

  // Exact Caliptra/Adams-Bridge continuous-lvalue shape, including a
  // one-element residual dimension and disjoint sibling row drivers.
  assign datapath[0] = storage_desc;
  assign datapath[1] = other_asc;
  assign datapath1[0] = single;

  task automatic check(input string what, input bit good);
    if (!good) begin
      errors++;
      $display("FAILED -- %s", what);
    end
  endtask

  initial begin
    src[ROW][3] = 8'hA3;
    src[ROW][2] = 8'hA2;
    src[ROW][1] = 8'hA1;

    src3[4][6][2] = 8'hC2;
    src3[4][6][3] = 8'hC3;
    src3[4][6][4] = 8'hC4;

    whole_src[3] = 8'h93;
    whole_src[2] = 8'h92;
    whole_src[1] = 8'h91;
    whole_dst = whole_src;
    whole_to_slice[1] = whole_src;

    holder = new;
    holder.words[3] = 8'h83;
    holder.words[2] = 8'h82;
    holder.words[1] = 8'h81;
    prop_dst = holder.words;

    enum_src[0][3] = E3;
    enum_src[0][2] = E2;
    enum_src[0][1] = E1;
    enum_dst = enum_src[0];

    struct_src[0][3] = '{hi: 4'hA, lo: 4'h3};
    struct_src[0][2] = '{hi: 4'hA, lo: 4'h2};
    struct_src[0][1] = '{hi: 4'hA, lo: 4'h1};
    struct_dst = struct_src[0];

    storage_desc[1] = 8'hD1;
    storage_desc[0] = 8'hD0;
    other_asc[0] = 8'hE0;
    other_asc[1] = 8'hE1;
    single[0] = 8'hF0;
    dst_slice[0][5] = 8'h75;
    dst_slice[0][6] = 8'h76;
    dst_slice[0][7] = 8'h77;

    #1;
    check("blocking opposite-direction copy",
          dst[5] === 8'hA3 && dst[6] === 8'hA2 && dst[7] === 8'hA1);
    check("procedural subarray l-value",
          dst_slice[1][5] === 8'hA3 && dst_slice[1][6] === 8'hA2 &&
          dst_slice[1][7] === 8'hA1);
    check("procedural subarray sibling preserved",
          dst_slice[0][5] === 8'h75 && dst_slice[0][6] === 8'h76 &&
          dst_slice[0][7] === 8'h77);
    check("two-prefix source",
          dst3[2] === 8'hC2 && dst3[3] === 8'hC3 &&
          dst3[4] === 8'hC4);
    check("whole-array opposite-direction copy",
          whole_dst[5] === 8'h93 && whole_dst[6] === 8'h92 &&
          whole_dst[7] === 8'h91);
    check("whole-array source to nonzero subarray destination",
          whole_to_slice[1][5] === 8'h93 &&
          whole_to_slice[1][6] === 8'h92 &&
          whole_to_slice[1][7] === 8'h91);
    check("class-property opposite-direction copy",
          prop_dst[5] === 8'h83 && prop_dst[6] === 8'h82 &&
          prop_dst[7] === 8'h81);
    check("enum subarray copy preserves element type",
          enum_dst[5] === E3 && enum_dst[6] === E2 && enum_dst[7] === E1);
    check("packed-struct subarray copy preserves element type",
          struct_dst[5] === 8'hA3 && struct_dst[6] === 8'hA2 &&
          struct_dst[7] === 8'hA1);
    check("continuous subarray l-value direction",
          datapath[0][0] === 8'hD1 && datapath[0][1] === 8'hD0);
    check("continuous sibling row",
          datapath[1][0] === 8'hE0 && datapath[1][1] === 8'hE1);
    check("one-element residual", datapath1[0][0] === 8'hF0);

    // This must retrigger the generated always_comb copy from the original
    // source net; a local structural view loses this sensitivity.
    src[ROW][2] = XZ_VALUE;
    #1;
    check("source sensitivity",
          dst[6] === XZ_VALUE && dst_slice[1][6] === XZ_VALUE);

    // The nonblocking copy captures the old row even though a source word is
    // updated into the same NBA region.
    clk = 1;
    src[ROW][3] <= 8'hB3;
    #1;
    check("nonblocking snapshot and direction",
          q[5] === 8'hA3 && q[6] === XZ_VALUE && q[7] === 8'hA1);
    check("nonblocking nonzero destination base",
          q_slice[1][5] === 8'hA3 && q_slice[1][6] === XZ_VALUE &&
          q_slice[1][7] === 8'hA1);
    check("whole-array nonblocking direction",
          whole_q[5] === 8'h93 && whole_q[6] === 8'h92 &&
          whole_q[7] === 8'h91);
    check("whole-array NBA to nonzero subarray destination",
          whole_to_slice_q[1][5] === 8'h93 &&
          whole_to_slice_q[1][6] === 8'h92 &&
          whole_to_slice_q[1][7] === 8'h91);

    if (errors == 0)
      $display("PASSED");
    $finish;
  end
endmodule
