// An event control on a bit of a virtual-interface member selected by a
// run-time index, @(cfg.vif.inputs[index]), wakes only when that bit changes.
// The packed class-property element select lowers its index through a checked
// canonicalizing function; null-validity tracking for the virtual-interface
// leaf must see through it. OpenTitan sysrst_ctrl's edge detector uses this.
interface sig_if;
  logic [7:0] inputs;
endinterface

class cfg_c;
  virtual sig_if vif;
endclass

class waiter;
  cfg_c cfg;
  bit woke[8];
  task wait_bit(int index);
    @(cfg.vif.inputs[index]);
    woke[index] = 1;
  endtask
endclass

module main;
  sig_if si();
  int errors;

  initial begin
    automatic waiter w = new;
    w.cfg = new;
    w.cfg.vif = si;
    si.inputs = 8'h00;

    // Wait on bit 5: other bits must not wake it, bit 5 must.
    fork
      w.wait_bit(5);
    join_none
    #10 si.inputs[1] = 1;
    #5  if (w.woke[5]) begin $display("FAILED bit 1 change woke index 5"); errors++; end
    #5  si.inputs[5] = 1;
    #5  if (!w.woke[5]) begin $display("FAILED bit 5 change did not wake index 5"); errors++; end

    // A later wait on a different index watches its own bit.
    fork
      w.wait_bit(2);
    join_none
    #10 si.inputs[4] = 1;
    #5  if (w.woke[2]) begin $display("FAILED bit 4 change woke index 2"); errors++; end
    #5  si.inputs[2] = 1;
    #5  if (!w.woke[2]) begin $display("FAILED bit 2 change did not wake index 2"); errors++; end

    if (errors == 0) $display("PASSED");
  end
endmodule
