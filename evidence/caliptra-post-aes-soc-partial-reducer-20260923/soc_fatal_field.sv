// Reduced from pinned Caliptra soc_ifc_top.sv:1376-1386 and
// soc_ifc_reg_pkg.sv:9-24. Compile with -DWHOLE_FIELD for the control.
package soc_field_pkg;
  typedef struct packed { logic next; logic we; } sticky_in_t;
  typedef struct packed { logic [27:0] next; } rsvd_in_t;
  typedef struct packed {
    sticky_in_t iccm_ecc_unc;
    sticky_in_t dccm_ecc_unc;
    sticky_in_t nmi_pin;
    sticky_in_t crypto_err;
    rsvd_in_t rsvd;
  } fatal_in_t;
  typedef struct packed {
    logic prefix;
    fatal_in_t CPTRA_HW_ERROR_FATAL;
    logic suffix;
  } reg_in_t;
endpackage

module reg_sink(input soc_field_pkg::reg_in_t hwif_in,
                output logic [35:0] observed);
  assign observed = hwif_in.CPTRA_HW_ERROR_FATAL;
endmodule

module top;
  import soc_field_pkg::*;
  logic iccm_error, dccm_error, fw_update_rst_window, nmi_intr, crypto_error;
  reg_in_t hwif_in;
  logic [35:0] observed;
  reg_sink sink(.hwif_in(hwif_in), .observed(observed));

  always_comb hwif_in.prefix = 1'b1;
  always_comb hwif_in.suffix = 1'b0;
`ifdef WHOLE_FIELD
  always_comb hwif_in.CPTRA_HW_ERROR_FATAL = {
    1'b1, iccm_error & ~fw_update_rst_window,
    1'b1, dccm_error & ~fw_update_rst_window,
    1'b1, nmi_intr,
    1'b1, crypto_error,
    28'b0
  };
`else
  always_comb hwif_in.CPTRA_HW_ERROR_FATAL.crypto_err.we = crypto_error;
  always_comb hwif_in.CPTRA_HW_ERROR_FATAL.iccm_ecc_unc.we = iccm_error & ~fw_update_rst_window;
  always_comb hwif_in.CPTRA_HW_ERROR_FATAL.dccm_ecc_unc.we = dccm_error & ~fw_update_rst_window;
  always_comb hwif_in.CPTRA_HW_ERROR_FATAL.nmi_pin.we = nmi_intr;
  always_comb hwif_in.CPTRA_HW_ERROR_FATAL.crypto_err.next = 1'b1;
  always_comb hwif_in.CPTRA_HW_ERROR_FATAL.iccm_ecc_unc.next = 1'b1;
  always_comb hwif_in.CPTRA_HW_ERROR_FATAL.dccm_ecc_unc.next = 1'b1;
  always_comb hwif_in.CPTRA_HW_ERROR_FATAL.nmi_pin.next = 1'b1;
  always_comb hwif_in.CPTRA_HW_ERROR_FATAL.rsvd.next[27:0] = 28'b0;
`endif

  task automatic check(input logic [35:0] expected, input int phase);
    if (hwif_in.CPTRA_HW_ERROR_FATAL !== expected || observed !== expected ||
        $isunknown(hwif_in.CPTRA_HW_ERROR_FATAL) !== $isunknown(expected))
      $fatal(1, "phase=%0d local=%h port=%h expected=%h", phase,
             hwif_in.CPTRA_HW_ERROR_FATAL, observed, expected);
    $display("phase=%0d local=%h port=%h", phase,
             hwif_in.CPTRA_HW_ERROR_FATAL, observed);
  endtask

  initial begin
    {iccm_error, dccm_error, fw_update_rst_window, nmi_intr, crypto_error} = 5'b00010;
    #2 check(36'hae0000000, 1);
    {iccm_error, dccm_error, fw_update_rst_window, nmi_intr, crypto_error} = 5'b10001;
    #2 check(36'heb0000000, 2);
    {iccm_error, dccm_error, fw_update_rst_window, nmi_intr, crypto_error} = 5'bx0000;
    #2 check({1'b1, 1'bx, 1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 28'b0}, 3);
    $display("PASS");
    $finish;
  end
endmodule
