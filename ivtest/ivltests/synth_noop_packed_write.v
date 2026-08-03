`begin_keywords "1800-2012"

module main;
  logic       clock;
  logic [3:0] data;
  logic [1:0] result;
  logic [1:0] stored;
  logic [1:0] default_x;
  logic [1:0] default_z;
  logic [1:0] standalone_x;
  logic [1:0] standalone_z;
  logic [1:0] memory_default [0:1];
  logic [1:0] memory_x [0:1];
  logic [1:0] memory_z [0:1];

  // A statically out-of-range procedural select writes no effective bit. It
  // must remain inert rather than claiming the whole vector, inferring a
  // latch, or tripping a synthesis invariant.
  always_comb result[9 +: 4] = data;
  always_ff @(posedge clock) stored[9 +: 4] <= data;

  // A contextually constant X/Z packed or unpacked index also writes no bit
  // or word. Cover both preservation of an earlier default and a standalone
  // no-op process, whose ordinary and synthesized values may be X and Z
  // respectively but must remain unknown in every bit.
  always_comb begin
    default_x = data[1:0];
    default_x[1'bx] = data[2];
  end
  always_comb begin
    default_z = data[3:2];
    default_z[1'bz] = data[1];
  end
  always_comb standalone_x[1'bx] = data[0];
  always_comb standalone_z[1'bz] = data[1];

  always_comb begin
    memory_default[0] = data[1:0];
    memory_default[1] = data[3:2];
    memory_default[1'bx] = data[1:0];
    memory_default[1'bz] = data[3:2];
  end
  always_comb memory_x[1'bx] = data[1:0];
  always_comb memory_z[1'bz] = data[3:2];

  (* ivl_synthesis_off *)
  initial begin
    clock = 1'b0;
    data = 4'b0101;
    #1;
    clock = 1'b1;
    #1;
    if (!$isunknown(result[0]) || !$isunknown(result[1]) ||
        !$isunknown(stored[0]) || !$isunknown(stored[1]) ||
        default_x !== data[1:0] || default_z !== data[3:2] ||
        memory_default[0] !== data[1:0] ||
        memory_default[1] !== data[3:2] ||
        !$isunknown(standalone_x[0]) || !$isunknown(standalone_x[1]) ||
        !$isunknown(standalone_z[0]) || !$isunknown(standalone_z[1]) ||
        !$isunknown(memory_x[0][0]) || !$isunknown(memory_x[0][1]) ||
        !$isunknown(memory_x[1][0]) || !$isunknown(memory_x[1][1]) ||
        !$isunknown(memory_z[0][0]) || !$isunknown(memory_z[0][1]) ||
        !$isunknown(memory_z[1][0]) || !$isunknown(memory_z[1][1])) begin
      $display("FAILED -- no-op write produced result=%b stored=%b defaults=%b/%b memory=%b/%b standalone=%b/%b memory_x=%b/%b memory_z=%b/%b",
               result, stored, default_x, default_z,
               memory_default[0], memory_default[1],
               standalone_x, standalone_z,
               memory_x[0], memory_x[1], memory_z[0], memory_z[1]);
      $finish;
    end
    clock = 1'b0;
    data = 4'b1010;
    #1;
    clock = 1'b1;
    #1;
    if (!$isunknown(result[0]) || !$isunknown(result[1]) ||
        !$isunknown(stored[0]) || !$isunknown(stored[1]) ||
        default_x !== data[1:0] || default_z !== data[3:2] ||
        memory_default[0] !== data[1:0] ||
        memory_default[1] !== data[3:2] ||
        !$isunknown(standalone_x[0]) || !$isunknown(standalone_x[1]) ||
        !$isunknown(standalone_z[0]) || !$isunknown(standalone_z[1]) ||
        !$isunknown(memory_x[0][0]) || !$isunknown(memory_x[0][1]) ||
        !$isunknown(memory_x[1][0]) || !$isunknown(memory_x[1][1]) ||
        !$isunknown(memory_z[0][0]) || !$isunknown(memory_z[0][1]) ||
        !$isunknown(memory_z[1][0]) || !$isunknown(memory_z[1][1])) begin
      $display("FAILED -- no-op write changed result=%b stored=%b defaults=%b/%b memory=%b/%b standalone=%b/%b memory_x=%b/%b memory_z=%b/%b",
               result, stored, default_x, default_z,
               memory_default[0], memory_default[1],
               standalone_x, standalone_z,
               memory_x[0], memory_x[1], memory_z[0], memory_z[1]);
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
