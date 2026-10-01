package pmp_pkg;
  typedef enum logic [1:0] {Off, Tor, Na4, Napot} mode_t;
  typedef struct packed {
    logic lock;
    mode_t mode;
    logic exec;
    logic write;
    logic read;
  } pmp_cfg_t;
endpackage

interface pmp_if;
  pmp_pkg::pmp_cfg_t pmp_cfg[16];
endinterface

module top;
  pmp_if intf();

  class pmp_checker;
    virtual pmp_if vif;

    function new(virtual pmp_if vif);
      this.vif = vif;
    endfunction

    function automatic logic [2:0] access(int unsigned idx);
      pmp_pkg::pmp_cfg_t entry;
      entry = vif.pmp_cfg[idx];
      return {entry.exec, entry.write, entry.read};
    endfunction

    task check();
`ifdef DIRECT
      if (vif.pmp_cfg[2][2:0] !== 3'b101) $fatal(1, "direct access mismatch");
`else
      if (access(2) !== 3'b101) $fatal(1, "local access mismatch");
`endif
    endtask
  endclass

  pmp_checker c;
  initial begin
    intf.pmp_cfg[2] = 6'b1_01_101;
    c = new(intf);
    c.check();
    $display("PASS");
  end
endmodule
