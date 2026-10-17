module sv_vpi_wide_index;
  reg [255:0] data;
  reg signed [127:0] idx;
  reg signed [64:0] odd_idx;
  reg signed [7:0] narrow_idx;
  reg [127:0] uidx;
  reg [7:0] four_state_idx;
  reg [7:0] got, expected;
  integer i, pattern, state;
  reg has_xz;

  initial begin
    data = {32{8'hA5}};

    idx = 128'sd248;
    got = data[idx +: 8];
    if (got !== data[248 +: 8])
      $fatal(1, "positive wide index mismatch: %h", got);

    idx = -128'sd5;
    got = data[idx +: 8];
    expected = data[-5 +: 8];
    if (got !== expected)
      $fatal(1, "negative sign-extended index mismatch: %h != %h", got, expected);

    odd_idx = -65'sd5;
    got = data[odd_idx +: 8];
    expected = data[-5 +: 8];
    if (got !== expected)
      $fatal(1, "65-bit negative index mismatch: %h != %h", got, expected);

    odd_idx = 0;
    odd_idx[64] = 1'bz;
    got = data[odd_idx +: 8];
    if (got !== 8'hxx)
      $fatal(1, "partial-word Z index must select X: %h", got);

    idx = 128'sd1 << 100;
    got = data[idx +: 8];
    if (got !== 8'hxx)
      $fatal(1, "large positive index must select X: %h", got);

    idx = -(128'sd1 << 100);
    got = data[idx +: 8];
    if (got !== 8'hxx)
      $fatal(1, "large negative index must select X: %h", got);

    uidx = 128'd1 << 100;
    got = data[uidx +: 8];
    if (got !== 8'hxx)
      $fatal(1, "large unsigned index must select X: %h", got);

    idx = 0;
    idx[100] = 1'bx;
    got = data[idx +: 8];
    if (got !== 8'hxx)
      $fatal(1, "X/Z index must select X: %h", got);

    idx = 0;
    idx[64] = 1'bz;
    got = data[idx +: 8];
    if (got !== 8'hxx)
      $fatal(1, "Z index must select X: %h", got);

    narrow_idx = 0;
    narrow_idx[3] = 1'bz;
    got = data[narrow_idx +: 8];
    if (got !== 8'hxx)
      $fatal(1, "narrow Z index must select X: %h", got);

    // Exercise every 4-state 8-bit index containing at least one X or Z.
    for (pattern = 0; pattern < 65536; pattern = pattern + 1) begin
      has_xz = 0;
      for (i = 0; i < 8; i = i + 1) begin
        state = (pattern >> (2 * i)) & 3;
        case (state)
          0: four_state_idx[i] = 1'b0;
          1: four_state_idx[i] = 1'b1;
          2: begin four_state_idx[i] = 1'bx; has_xz = 1; end
          3: begin four_state_idx[i] = 1'bz; has_xz = 1; end
        endcase
      end
      if (has_xz) begin
        got = data[four_state_idx +: 8];
        if (got !== 8'hxx)
          $fatal(1, "4-state index must select X: %h", got);
      end
    end

    $display("PASSED");
    $finish;
  end
endmodule
