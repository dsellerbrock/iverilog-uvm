package array_parameter_nested_struct_pattern_pkg;
  typedef enum logic [1:0] {
    ModeOff = 2'b00,
    ModeTor = 2'b01
  } mode_e;

  typedef struct packed {
    logic       lock;
    mode_e      mode;
    logic [4:0] address;
  } pmp_cfg_t;

  localparam pmp_cfg_t PmpCfg[2] = '{
    '{lock: 1'b0, mode: ModeOff, address: 5'h03},
    '{lock: 1'b1, mode: ModeTor, address: 5'h1a}
  };

  typedef struct packed {
    mode_e [1:0] scan_role;
  } target_cfg_t;

  localparam target_cfg_t TargetCfg = '{scan_role: {ModeTor, ModeOff}};
endpackage

module array_parameter_nested_struct_pattern_test;
  import array_parameter_nested_struct_pattern_pkg::*;

  localparam logic [4:0] Address1 = PmpCfg[1].address;
  localparam mode_e Mode1 = PmpCfg[1].mode;

  for (genvar k = 0; k < 2; k++) begin : gen_member_select
    if (PmpCfg[k].lock == (k == 1)) begin : gen_expected_lock
      localparam logic Matched = 1'b1;
    end else begin : gen_bad_lock
      localparam logic Matched = 1'b0;
    end
  end

  for (genvar k = 0; k < 2; k++) begin : gen_indexed_member_select
    if (TargetCfg.scan_role[k] == (k == 0 ? ModeOff : ModeTor)) begin : gen_expected_role
      localparam logic Matched = 1'b1;
    end else begin : gen_bad_role
      localparam logic Matched = 1'b0;
    end
  end

  initial begin
    if (PmpCfg[0] !== 8'h03)
      $fatal(1, "PmpCfg[0] was not contextually typed: %h", PmpCfg[0]);
    if (PmpCfg[1] !== 8'hba)
      $fatal(1, "PmpCfg[1] was not contextually typed: %h", PmpCfg[1]);
    if (Address1 !== 5'h1a || Mode1 !== ModeTor)
      $fatal(1, "packed member selection failed: address=%h mode=%h", Address1, Mode1);
    if (!gen_member_select[0].gen_expected_lock.Matched ||
        !gen_member_select[1].gen_expected_lock.Matched)
      $fatal(1, "genvar-indexed parameter member selection failed");
    if (!gen_indexed_member_select[0].gen_expected_role.Matched ||
        !gen_indexed_member_select[1].gen_expected_role.Matched)
      $fatal(1, "packed-array member selection failed");
    $display("PASS: nested struct patterns inherit array parameter element type");
  end
endmodule
