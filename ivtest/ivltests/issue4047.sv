// IEEE 1800-2017/2023 23.3.2, 23.3.3.5, 23.6 and 23.11.
module issue4047_leaf;
  integer value;
  wire marked;
endmodule

module issue4047_marker(output wire hit);
  assign hit = 1'b1;
endmodule

module issue4047_copy(input wire [3:0] d, output wire [3:0] q,
                      input wire [1:0] common);
  assign q = d;
endmodule

module issue4047_bidirectional(inout wire bus, input wire drive);
  assign bus = drive ? 1'b1 : 1'bz;
endmodule

module issue4047_arrays #(parameter integer LEFT = -1);
  localparam integer LAST = 5;
  issue4047_leaf u[LEFT:-1][3:LAST]();
  bind u[-1][LAST-1] issue4047_marker selected(.hit(marked));

  localparam logic [23:0] WORDS = {4'b01xz, 4'b10zx, 4'b001x,
                                  4'bz110, 4'bx001, 4'bzx11};
  logic [23:0] packed_in;
  wire [0:23] packed_out;
  logic [1:0] common;
  issue4047_copy packed_copy[LEFT:-1][3:LAST](packed_in, packed_out, common);

  // Left-to-right element order depends on each actual's own bounds.
  logic [3:0] unpacked_in[7:8][5:3][11:11];
  wire [3:0] unpacked_out[2:1][-4:-2][15:15];
  issue4047_copy unpacked_copy[LEFT:-1][3:LAST][7:7](
    unpacked_in, unpacked_out, common);

  wire bus[7:8][5:3];
  issue4047_bidirectional transceivers[LEFT:-1][3:LAST](bus, 6'b100000);
  assign bus[8][3] = 1'b0;

  initial begin
    u[0][3].value = 10;
    u[0][4].value = 11;
    u[0][5].value = 12;
    u[-1][3].value = 20;
    u[-1][4].value = 21;
    u[-1][5].value = 22;
    if ({u[0][3].value, u[0][4].value, u[0][5].value,
         u[-1][3].value, u[-1][4].value, u[-1][5].value}
        !== {32'd10, 32'd11, 32'd12, 32'd20, 32'd21, 32'd22})
      $fatal(1, "portless instance tuple storage");

    packed_in = WORDS;
    common = 2'bzx;
    {unpacked_in[7][5][11], unpacked_in[7][4][11], unpacked_in[7][3][11],
     unpacked_in[8][5][11], unpacked_in[8][4][11], unpacked_in[8][3][11]}
        = WORDS;
    #1;
    if ({u[0][3].marked, u[0][4].marked, u[0][5].marked,
         u[-1][3].marked, u[-1][4].marked, u[-1][5].marked} !== 6'bzzzz1z
        || u[-1][4].selected.hit !== 1'b1)
      $fatal(1, "bind must reach only the selected tuple");
    if ({packed_copy[0][3].d, packed_copy[0][4].d, packed_copy[0][5].d,
         packed_copy[-1][3].d, packed_copy[-1][4].d, packed_copy[-1][5].d}
        !== WORDS || packed_out !== WORDS)
      $fatal(1, "packed input or output slicing");
    if ({packed_copy[0][3].common, packed_copy[0][4].common,
         packed_copy[0][5].common, packed_copy[-1][3].common,
         packed_copy[-1][4].common, packed_copy[-1][5].common} !== {6{2'bzx}})
      $fatal(1, "packed broadcast");
    if ({unpacked_copy[0][3][7].d, unpacked_copy[0][4][7].d,
         unpacked_copy[0][5][7].d, unpacked_copy[-1][3][7].d,
         unpacked_copy[-1][4][7].d, unpacked_copy[-1][5][7].d} !== WORDS
        || {unpacked_out[2][-4][15], unpacked_out[2][-3][15],
            unpacked_out[2][-2][15], unpacked_out[1][-4][15],
            unpacked_out[1][-3][15], unpacked_out[1][-2][15]} !== WORDS)
      $fatal(1, "unpacked port mapping");
    if ({bus[7][5], bus[7][4], bus[7][3], bus[8][5], bus[8][4], bus[8][3]}
          !== 6'b1zzzz0 || transceivers[-1][5].bus !== 1'b0)
      $fatal(1, "unpacked inout mapping");
  end
endmodule

module issue4047_named;
  string hier_name;
  initial hier_name = $sformatf("%m");
endmodule

module issue4047;
  issue4047_arrays array_checks();
  defparam array_checks.LEFT = 0;

  localparam signed [79:0] MIN_INDEX = -80'sd2147483648;
  wire [3:0] singleton_out;
  issue4047_copy singleton[32'sh7fffffff:32'sh7fffffff][MIN_INDEX:MIN_INDEX](
    4'bz01x, singleton_out, 2'b00);

  // Eighty indices make the instance name exceed 1024 bytes.
`define ISSUE4047_DIM [MIN_INDEX:MIN_INDEX]
`define ISSUE4047_DIMS `ISSUE4047_DIM `ISSUE4047_DIM `ISSUE4047_DIM `ISSUE4047_DIM \
                      `ISSUE4047_DIM `ISSUE4047_DIM `ISSUE4047_DIM `ISSUE4047_DIM
`define ISSUE4047_SEL [MIN_INDEX]
`define ISSUE4047_SELS `ISSUE4047_SEL `ISSUE4047_SEL `ISSUE4047_SEL `ISSUE4047_SEL \
                      `ISSUE4047_SEL `ISSUE4047_SEL `ISSUE4047_SEL `ISSUE4047_SEL
  issue4047_named long_tuple
    `ISSUE4047_DIMS `ISSUE4047_DIMS `ISSUE4047_DIMS `ISSUE4047_DIMS `ISSUE4047_DIMS
    `ISSUE4047_DIMS `ISSUE4047_DIMS `ISSUE4047_DIMS `ISSUE4047_DIMS `ISSUE4047_DIMS ();
  string hier_name;
  initial begin
    #2;
    if (singleton_out !== 4'bz01x || singleton[32'sh7fffffff][MIN_INDEX].d !== 4'bz01x)
      $fatal(1, "multidimensional singleton");
    hier_name = long_tuple
      `ISSUE4047_SELS `ISSUE4047_SELS `ISSUE4047_SELS `ISSUE4047_SELS `ISSUE4047_SELS
      `ISSUE4047_SELS `ISSUE4047_SELS `ISSUE4047_SELS `ISSUE4047_SELS `ISSUE4047_SELS.hier_name;
    if (hier_name.len() != 20 + 80 * 13)
      $fatal(1, "long tuple name length %d", hier_name.len());
    $display("PASSED");
  end
`undef ISSUE4047_DIM
`undef ISSUE4047_DIMS
`undef ISSUE4047_SEL
`undef ISSUE4047_SELS
endmodule

module issue4047_select_error;
  issue4047_leaf u[0:1][-1:1]();
  int row;
  initial begin
    $display("%d", u[0].value);
    $display("%d", u[1][2].value);
    $display("%d", u[row][-1].value);
  end
endmodule

module issue4047_unpacked_formal(input wire [3:0] a[2]);
endmodule

module issue4047_port_error;
  wire [3:0] wrong[3][2];
  issue4047_copy shape[2][3](wrong, , 2'b00);
  issue4047_copy width_check[1][1](2'b10 ^ 2'b01, , 2'b00);
  wire [3:0] rows[2][3][2];
  issue4047_unpacked_formal unsupported[2][3](rows);
  issue4047_copy output_shape[2][3](4'b0, wrong, 2'b00);
  wire bus[3][2];
  issue4047_bidirectional inout_shape[2][3](bus, 1'b0);
endmodule
