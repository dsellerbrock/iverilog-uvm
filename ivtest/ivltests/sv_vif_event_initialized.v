// IEEE 1800-2017 25.9: a virtual interface may be used after it has been
// initialized with a compatible interface instance. Pin all VVP dynamic
// event-wait opcodes while proving that the fatal null-handle checks do not
// affect live handles.

interface vif_event_if;
  logic signal;
  logic other;
endinterface

module sv_vif_event_initialized;
  vif_event_if actual();
  virtual vif_event_if vif;

  bit posedge_woke;
  bit negedge_woke;
  bit anyedge_woke;
  bit multi_woke;

  initial begin
    vif = actual;
    actual.signal = 0;
    actual.other = 0;

    fork
      begin
        @(posedge vif.signal);
        posedge_woke = 1;
      end
      begin
        @(negedge vif.signal);
        negedge_woke = 1;
      end
      begin
        @(vif.other);
        anyedge_woke = 1;
      end
      begin
        @(vif.signal or vif.other);
        multi_woke = 1;
      end
    join_none

    #1 actual.signal = 1;
    #1 actual.signal = 0;
    #1 actual.other = 1;
    #1;

    if (!posedge_woke || !negedge_woke || !anyedge_woke || !multi_woke) begin
      $display("FAILED pos=%0d neg=%0d any=%0d multi=%0d",
               posedge_woke, negedge_woke, anyedge_woke, multi_woke);
    end else begin
      $display("PASSED");
    end
  end
endmodule
