`timescale 1ns/1ps

// IEEE 1800-2023 21.7.3/21.7.4: direction states, strengths, reals,
// concatenated declaration components, controls, and deterministic ordering.
module dumpports_dut(
    input  wire       in_s,
    input  wire [3:0] in_v,
    input       real  real_in,
    output wire       out_s,
    output wire [3:0] out_v,
    output      real  real_out,
    input  wire       multi_in,
    output wire       multi_out,
    input  wire       multi_out_second,
    input  wire       dut_enable,
    input  wire       dut_value,
    inout  wire       io,
    inout  wire       unconnected_io,
    inout  wire       z_connected_io
);
  assign out_s = ~in_s;
  assign out_v = in_v ^ 4'ha;
  assign real_out = real_in + 0.25;
  assign (strong1, strong0) multi_out = 1'b0;
  assign (strong1, strong0) multi_out = multi_out_second ? 1'b0 : 1'bz;
  assign (weak1, weak0) io = dut_enable ? dut_value : 1'bz;
endmodule

module dumpports_concat({whole_a, whole_b},
                        {selected_bus[3:2], selected_bus[1:0]}, result);
  input whole_a, whole_b;
  input [3:0] selected_bus;
  output result;
  assign result = whole_a ^ whole_b ^ ^selected_bus;
endmodule

module sv_dumpports_runtime;
  reg in_value;
  reg in_strong;
  tri in_s;
  reg [3:0] in_v;
  real real_drive;
  real real_in;
  real real_out;
  wire out_s;
  wire [3:0] out_v;
  reg multi_in_second, multi_out_second;
  tri multi_in;
  wire multi_out;
  reg dut_enable, dut_value;
  reg fixture_enable, fixture_value;
  reg fixture2_enable, fixture2_value;
  tri io;
  tri z_connected_io;
  reg z_connected_enable;
  reg whole_a, whole_b;
  reg [3:0] selected_bus;
  wire result;
  string filename = "work/sv_dumpports_runtime.evcd";

  assign (strong1, strong0) in_s = in_strong ? in_value : 1'bz;
  assign (weak1, weak0) in_s = in_strong ? 1'bz : in_value;
  assign real_in = real_drive;
  assign (strong1, strong0) multi_in = 1'b0;
  assign (strong1, strong0) multi_in = multi_in_second ? 1'b0 : 1'bz;
  assign (strong1, strong0) io = fixture_enable ? fixture_value : 1'bz;
  assign (pull1, pull0) io = fixture2_enable ? fixture2_value : 1'bz;
  assign z_connected_io = z_connected_enable ? 1'b0 : 1'bz;

  dumpports_dut dut(.in_s(in_s), .in_v(in_v), .real_in(real_in),
                    .out_s(out_s), .out_v(out_v), .real_out(real_out),
                    .multi_in(multi_in), .multi_out(multi_out),
                    .multi_out_second(multi_out_second),
                    .dut_enable(dut_enable), .dut_value(dut_value), .io(io),
                    .unconnected_io(), .z_connected_io(z_connected_io));
  dumpports_concat concat_dut({whole_a, whole_b}, selected_bus, result);

  initial begin
    in_value = 1'b0;
    in_strong = 1'b0;
    in_v = 4'b0011;
    real_drive = 1.5;
    multi_in_second = 1'b0;
    multi_out_second = 1'b0;
    dut_enable = 1'b0;
    dut_value = 1'b0;
    fixture_enable = 1'b0;
    fixture_value = 1'b0;
    fixture2_enable = 1'b0;
    fixture2_value = 1'b0;
    z_connected_enable = 1'b0;
    whole_a = 1'b0;
    whole_b = 1'b1;
    selected_bus = 4'b0110;
    $dumpports(dut, concat_dut, filename);
    $dumpportslimit(100000, filename);

    // Same logic, different strength and same-value driver-count changes
    // must still produce records. Ordinary VPI cbValueChange remains a
    // resolved-value event; the count-only wakeup is private to EVCD.
    #1 begin
      in_strong = 1'b1;
      multi_in_second = 1'b1;
      multi_out_second = 1'b1;
    end

    #1 begin
      in_value = 1'b1;
      multi_in_second = 1'b0;
      multi_out_second = 1'b0;
      in_v = 4'b1100;
      real_drive = 2.5;
      fixture_enable = 1'b1;
      fixture_value = 1'b0;
      fixture2_enable = 1'b1;
      fixture2_value = 1'b0;
      selected_bus = 4'b1001;
    end

    // Two active drivers on the fixture side require lowercase d. Dropping
    // one driver while retaining the same resolved value requires uppercase D.
    #1 fixture2_enable = 1'b0;

    // Both hierarchy sides drive zero; fixture strong beats DUT weak.
    #1 begin
      dut_enable = 1'b1;
      dut_value = 1'b0;
    end

    // Fixture one versus DUT zero exercises an explicit conflict state.
    #1 fixture_value = 1'b1;

    // DUT is now the only active side.
    #1 begin
      fixture_enable = 1'b0;
      dut_value = 1'b1;
    end

    #1 begin
      $dumpportsoff(filename);
      in_value = 1'b0;
      in_v = 4'b1111;
      real_drive = 7.0;
    end

    #1 begin
      in_value = 1'b1;
      in_v = 4'b0101;
    end

    #1 $dumpportson(filename);
    #1 $dumpportsall(filename);

    #1 begin
      $dumpportsflush("work/not-open.evcd");
      $dumpportsflush(filename);
      $dumpportsflush;
      $display("PASSED");
    end
  end
endmodule
