package release_types;
  typedef enum logic [7:0] {Zero = 8'h00, One = 8'h01} member_t;
  typedef struct packed {member_t read_lock, write_lock;} access_t;
endpackage

module release_dut;
  release_types::access_t [1:0] part_access;
endmodule

module release_net_dut;
  release_types::access_t [1:0] source;
  wire release_types::access_t [1:0] part_access = source;
endmodule

module test;
  release_dut dut();
  release_net_dut net_dut();
  release_types::member_t sample [0:0];
  release_types::access_t [1:0] variable_access;
  logic [15:0] source;
  wire [15:0] bus = source;
  logic [1:0][7:0] packed_value;

  initial begin
    source = 16'h1234;
    #1 force bus[7:4] = 4'ha;
    #1 if (bus !== 16'h12a4) $fatal(1, "constant force value=%h", bus);
    release bus[7:4];
    #1 if (bus !== 16'h1234) $fatal(1, "constant release value=%h", bus);

    packed_value = 16'h1234;
    force packed_value[0][3:0] = 4'hf;
    if (packed_value !== 16'h123f)
      $fatal(1, "packed array force changed value=%h", packed_value);
    release packed_value[0][3:0];
    if (packed_value !== 16'h123f)
      $fatal(1, "packed array variable release changed value=%h", packed_value);
    packed_value = '0;
    if (packed_value !== '0)
      $fatal(1, "packed array force remained after release");

    dut.part_access = '0;
    sample[0] = release_types::One;
    force dut.part_access[0].read_lock = sample[0];
    if (dut.part_access[0].read_lock !== release_types::One ||
        dut.part_access[0].write_lock !== release_types::Zero ||
        dut.part_access[1] !== '0)
      $fatal(1, "packed member force changed unrelated bits");
    release dut.part_access[0].read_lock;
    if (dut.part_access[0].read_lock !== release_types::One ||
        dut.part_access[0].write_lock !== release_types::Zero ||
        dut.part_access[1] !== '0)
      $fatal(1, "packed member release changed unrelated bits");
    dut.part_access = '0;
    if (dut.part_access !== '0)
      $fatal(1, "packed member force remained after release");

    net_dut.source = '0;
    force net_dut.part_access[0].read_lock = sample[0];
    if (net_dut.part_access[0].read_lock !== release_types::One ||
        net_dut.part_access[0].write_lock !== release_types::Zero ||
        net_dut.part_access[1] !== '0)
      $fatal(1, "packed net member force changed unrelated bits");
    release net_dut.part_access[0].read_lock;
    if (net_dut.part_access !== '0)
      $fatal(1, "packed net member release did not restore the driver");

    variable_access = '0;
    force variable_access[0].read_lock = sample[0];
    release variable_access[0].read_lock;
    if (variable_access[0].read_lock !== release_types::One ||
        variable_access[0].write_lock !== release_types::Zero)
      $fatal(1, "packed variable member release changed unrelated bits");
    variable_access = '0;
    if (variable_access !== '0)
      $fatal(1, "packed variable member force remained after release");

    $display("PASSED");
  end
endmodule
