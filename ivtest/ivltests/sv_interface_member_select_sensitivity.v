interface selected_member_if;
  logic [15:0] address;
  logic [7:0] bank[2];
  logic [7:0] window[3:2];
  logic edge_word[3:2];
endinterface

module selected_member_reader(
  selected_member_if bus,
  input logic enable,
  input logic index_select,
  input logic latch_enable,
  output logic [7:0] address_byte,
  output logic [3:0] bank_nibble[2],
  output logic [7:0] mixed_value,
  output logic [3:0] combined_value,
  output logic [3:0] dynamic_nibble,
  output logic [7:0] legacy_byte,
  output logic [3:0] latched_nibble,
  output integer window_posedges
);
  initial window_posedges = 0;

  always_comb begin
    address_byte = 8'(bus.address[11:4]);
  end

  for (genvar i = 0; i < 2; i++) begin : gen_bank
    always_comb begin
      bank_nibble[i] = bus.bank[i][5:2];
    end
  end

  // A dynamic unpacked index observes all words conservatively and observes
  // the index expression exactly. The declaration is descending and has a
  // nonzero lower bound, pinning canonical word-number transport to VVP.
  always_comb dynamic_nibble = bus.window[2 + index_select][5:2];

  // Keep ordinary-net dependencies alongside one or more interface-member
  // dependencies. Removing the handle carrier must not remove `enable'.
  always_comb mixed_value = bus.address[7:0] ^ (enable ? 8'hff : 8'h00);
  always_comb combined_value = bus.address[3:0] ^ bus.bank[0][3:0];

  // The same implicit-event machinery serves plain always @* and
  // always_latch, including the latter's ordinary enable dependency.
  always @* legacy_byte = bus.address[15:8];
  always_latch if (latch_enable) latched_nibble = bus.window[2][5:2];

  // An explicit edge wait on a constant scalar element uses the indexed VIF
  // event opcode without relying on multibit edge-expression semantics.
  always @(posedge bus.edge_word[2]) window_posedges++;
endmodule

module sv_interface_member_select_sensitivity;
  selected_member_if bus();
  logic enable;
  logic index_select;
  logic latch_enable;
  logic [7:0] address_byte;
  logic [3:0] bank_nibble[2];
  logic [7:0] mixed_value;
  logic [3:0] combined_value;
  logic [3:0] dynamic_nibble;
  logic [7:0] legacy_byte;
  logic [3:0] latched_nibble;
  integer window_posedges;

  selected_member_reader dut(
    .bus(bus),
    .enable(enable),
    .index_select(index_select),
    .latch_enable(latch_enable),
    .address_byte(address_byte),
    .bank_nibble(bank_nibble),
    .mixed_value(mixed_value),
    .combined_value(combined_value),
    .dynamic_nibble(dynamic_nibble),
    .legacy_byte(legacy_byte),
    .latched_nibble(latched_nibble),
    .window_posedges(window_posedges)
  );

  initial begin
    enable = 0;
    index_select = 0;
    latch_enable = 1;
    bus.address = 16'hca5e;
    bus.bank[0] = 8'b1010_1100;
    bus.bank[1] = 8'b0111_0011;
    bus.window[2] = 8'b0001_0000;
    bus.window[3] = 8'b1010_0100;
    bus.edge_word[2] = 0;
    bus.edge_word[3] = 0;
    #1;
    if (address_byte !== 8'ha5 || bank_nibble[0] !== 4'b1011 ||
        bank_nibble[1] !== 4'b1100 || mixed_value !== 8'h5e ||
        combined_value !== 4'h2 || dynamic_nibble !== 4'b0100 ||
        legacy_byte !== 8'hca || latched_nibble !== 4'b0100 ||
        window_posedges !== 0)
      $fatal(1, "initial selected member values are wrong");

    bus.address = 16'h03c0;
    bus.bank[0] = 8'b0001_0100;
    bus.bank[1] = 8'b0010_0100;
    bus.window[2] = 8'b0001_0101;
    bus.edge_word[2] = 1;
    #1;
    if (address_byte !== 8'h3c || bank_nibble[0] !== 4'b0101 ||
        bank_nibble[1] !== 4'b1001 || mixed_value !== 8'hc0 ||
        combined_value !== 4'h4 || dynamic_nibble !== 4'b0101 ||
        legacy_byte !== 8'h03 || latched_nibble !== 4'b0101 ||
        window_posedges !== 1)
      $fatal(1, "selected member changes did not retrigger: addr=%h bank=%h/%h mixed=%h combined=%h dynamic=%h legacy=%h latch=%h edges=%0d",
             address_byte, bank_nibble[0], bank_nibble[1], mixed_value,
             combined_value, dynamic_nibble, legacy_byte, latched_nibble,
             window_posedges);

    // Index changes are ordinary sensitivity inputs; the newly selected
    // descending-array element then remains dynamically observed.
    index_select = 1;
    enable = 1;
    #1;
    if (dynamic_nibble !== 4'b1001 || mixed_value !== 8'h3f)
      $fatal(1, "index or mixed ordinary-net dependency did not retrigger");
    bus.window[3] = 8'b0011_1000;
    #1;
    if (dynamic_nibble !== 4'b1110)
      $fatal(1, "runtime-selected interface array word did not retrigger");

    // When disabled, always_latch must retain its value despite a member
    // change; re-enabling and a later member change must each retrigger it.
    latch_enable = 0;
    bus.window[2] = 8'b0110_0000;
    #1;
    if (latched_nibble !== 4'b0101 || window_posedges !== 1)
      $fatal(1, "disabled interface-member latch changed unexpectedly");
    latch_enable = 1;
    #1;
    if (latched_nibble !== 4'b1000)
      $fatal(1, "always_latch enable dependency did not retrigger");
    bus.window[2] = 8'b0111_1101;
    bus.edge_word[2] = 0;
    bus.edge_word[2] = 1;
    #1;
    if (latched_nibble !== 4'b1111 || window_posedges !== 2)
      $fatal(1, "enabled interface-member latch did not retrigger");

    $display("PASSED");
  end
endmodule
