module empty;
endmodule

module top;
  reg [1:0] drive;
  wire a, b;
  alias a = b;
  assign a = drive[0];

  wire c0, c1, c2, c3;
  alias c0 = c1 = c2 = c3;
  assign c0 = drive[1];

  wire [2:5] ascending;
  wire [1:0] slice_rhs;
  alias ascending[3:4] = slice_rhs;
  assign slice_rhs = drive;

  wire cat_hi, cat_lo;
  wire [1:0] cat_rhs;
  alias {cat_hi, cat_lo} = cat_rhs;
  assign cat_rhs = drive;

  wire [5:2] bank [2:3];
  wire [1:0] word_rhs;
  alias bank[2][4:3] = word_rhs;
  assign word_rhs = drive;

  wire [1:0][5:2] packed_bus;
  wire [1:0] packed_rhs;
  alias packed_bus[1][3+:2] = packed_rhs;
  assign packed_rhs = drive;

  wire [1:0][5:2] rows;
  wire [5:2] row_rhs;
  alias rows[0] = row_rhs;
  assign row_rhs = {2'b01, drive};

  wire pat_hi, pat_lo;
  wire [1:0] pat_rhs;
  alias '{pat_hi, pat_lo} = pat_rhs;
  assign pat_rhs = drive;

  wire [1:-1] bits;
  wire bit_rhs;
  alias bits[-1] = bit_rhs;
  assign bit_rhs = drive[0];

  wire source_tran, through_tran;
  assign source_tran = drive[1];
  tran unit_switch(through_tran, source_tran);

  for (genvar i = 0; i < 2; i = i+1) begin : g
    wire x, y;
    alias x = y;
    assign x = drive[i];
  end

  empty no_alias();

  typedef struct packed { logic [1:0][5:2] f; logic g; } record_t;
  wire record_t record;
  wire [1:0] member_rhs;
  alias record.f[1][3:2] = member_rhs;
  assign member_rhs = drive;

  typedef struct packed { logic [1:0] \field. ; logic g; } odd_t;
  wire odd_t odd;
  wire [1:0] odd_rhs;
  alias odd.\field.  = odd_rhs;
  assign odd_rhs = drive;

  wire [1:0] matrix [4:5][1:1], matrix_rhs [4:5][1:1];
  alias matrix[5] = matrix_rhs[5];
  assign matrix_rhs[5][1] = drive;

  task check_connectivity;
    if (b !== drive[0] || {c1,c2,c3} !== {3{drive[1]}} ||
        ascending[3:4] !== drive || {cat_hi,cat_lo} !== drive ||
        bank[2][4:3] !== drive || packed_bus[1][3+:2] !== drive ||
        rows[0] !== {2'b01, drive} || {pat_hi,pat_lo} !== drive ||
        bits[-1] !== drive[0] || through_tran !== drive[1] ||
        {g[1].y,g[0].y} !== drive ||
        record.f[1][3:2] !== drive || odd.\field.  !== drive ||
        matrix[5][1] !== drive)
      $fatal(1, "alias connectivity");
  endtask

  initial begin
    drive = 2'b10;
    #1;
    check_connectivity;
    $inspect_alias(1'b0);
    drive = 2'b01;
    #1;
    check_connectivity;
    $inspect_alias(1'b1);
  end
endmodule
