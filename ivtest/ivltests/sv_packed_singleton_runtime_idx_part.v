// A packed element index is normalized before the width of the remaining
// dimensions is applied as its stride. In particular, the degenerate [0:0]
// range has no direction that may turn the element access into a -: select.
module sv_packed_singleton_runtime_idx_part;

  localparam int WidthMult = 1;

  logic [WidthMult-1:0][31:0] singleton;
  logic [1:0][31:0]           descending;
  logic [0:1][31:0]           ascending;
  logic                       outer_index;
  logic [3:0]                 byte_mask;
  integer                     inner_base;
  integer                     errors = 0;

  task automatic check8(input string tag,
                        input logic [7:0] got,
                        input logic [7:0] expected);
    if (got !== expected) begin
      $display("FAIL %0s: got %02h expected %02h", tag, got, expected);
      errors = errors + 1;
    end
  endtask

  task automatic check32(input string tag,
                         input logic [31:0] got,
                         input logic [31:0] expected);
    if (got !== expected) begin
      $display("FAIL %0s: got %08h expected %08h", tag, got, expected);
      errors = errors + 1;
    end
  endtask

  task automatic check64(input string tag,
                         input logic [63:0] got,
                         input logic [63:0] expected);
    if (got !== expected) begin
      $display("FAIL %0s: got %016h expected %016h", tag, got, expected);
      errors = errors + 1;
    end
  endtask

  initial begin
    // This is the parameterized OpenTitan shape. Both the outer index and
    // inner indexed-part base are run-time expressions.
    singleton = '0;
    outer_index = 1'b0;
    byte_mask = 4'b1010;
    for (int i = 0; i < 4; i++) begin
      inner_base = 8*i;
      singleton[outer_index][inner_base +: 8] = {8{byte_mask[i]}};
    end
    check32("singleton write", singleton, 32'hff00_ff00);
    inner_base = 8;
    check8("singleton read", singleton[outer_index][inner_base +: 8],
           8'hff);

    // Descending and ascending outer dimensions must use opposite
    // canonical element orders while sharing the same inner select rules.
    descending = '0;
    outer_index = 1'b0;
    inner_base = 0;
    descending[outer_index][inner_base +: 8] = 8'hff;
    outer_index = 1'b1;
    inner_base = 15;
    descending[outer_index][inner_base -: 8] = 8'hff;
    check64("descending outer", descending, 64'h0000_ff00_0000_00ff);

    ascending = '0;
    outer_index = 1'b0;
    inner_base = 0;
    ascending[outer_index][inner_base +: 8] = 8'hff;
    outer_index = 1'b1;
    inner_base = 15;
    ascending[outer_index][inner_base -: 8] = 8'hff;
    check64("ascending outer", ascending, 64'h0000_00ff_0000_ff00);

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED with %0d errors", errors);
  end

endmodule
