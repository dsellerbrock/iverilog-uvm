module sv_deferred_vpi_kill_leaf(output bit queued);
  initial begin : child_process
    assert #0 (1'b0) else $display("CHILD_REPORT");
    queued = 1;
  end
endmodule

module sv_deferred_vpi_kill0;
  bit child_queued;
  sv_deferred_vpi_kill_leaf child(child_queued);

  initial begin : vpi_target
    assert #0 (1'b0) else $display("TOP_REPORT");
    wait (child_queued);
  end

  initial begin
    wait (child_queued);
    #0;
    $assertkill(1, sv_deferred_vpi_kill0);
    $check_deferred_kill_callbacks;
  end
endmodule
