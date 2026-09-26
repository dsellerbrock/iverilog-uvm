// IEEE 1800-2017/2023 13.4.2: a zero-argument function may be called
// without parentheses, including the built-in process::self (9.7).
// Reduced from OpenTitan lc_ctrl_errors_vseq.sv:795 (handle_alerts).
class alert_handler;
  process handle_alerts_process;
  task handle_alerts();
    handle_alerts_process = process::self;
    #10;
  endtask
endclass

module test;
  alert_handler h;
  process p_parenless, p_parens;
  bit failed = 0;

  initial begin
    p_parenless = process::self;
    p_parens = process::self();
    if (p_parenless == null || p_parenless != p_parens) begin
      $display("FAILED: module-scope process::self");
      failed = 1;
    end
    h = new;
    fork h.handle_alerts(); join_none
    #1;
    if (h.handle_alerts_process == null
        || h.handle_alerts_process == p_parenless
        || h.handle_alerts_process.status() != process::WAITING) begin
      $display("FAILED: class-method process::self");
      failed = 1;
    end
    h.handle_alerts_process.kill();
    #1;
    if (h.handle_alerts_process.status() != process::KILLED) begin
      $display("FAILED: handle does not control its process");
      failed = 1;
    end
    if (!failed) $display("PASSED");
  end
endmodule
