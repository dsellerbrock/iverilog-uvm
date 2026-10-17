module sv_deferred_vpi_reset0;
  initial begin : vpi_process
    #1;
    vpi_target: assert #0 (0)
      $display("VPI_TARGET_STALE_PASS");
    else $display("VPI_TARGET_STALE_FAIL");
    vpi_sibling: assert #0 (1) $display("VPI_SIBLING");
    vpi_final_target: assert final (0)
      $display("VPI_FINAL_STALE_PASS");
    else $display("VPI_FINAL_STALE_FAIL");
    vpi_final_sibling: assert final (1) $display("VPI_FINAL_SIBLING");
    begin : vpi_shared
      assert #0 (1) $display("VPI_SHARED_SURVIVOR");
      assert #0 (1) $display("VPI_SHARED_SURVIVOR");
    end
    begin : vpi_final_shared
      assert final (1) $display("VPI_FINAL_SHARED_SURVIVOR");
      assert final (1) $display("VPI_FINAL_SHARED_SURVIVOR");
    end
    begin : vpi_kinds
      assume #0 (1);
      cover #0 (1);
    end
    $reset_deferred_assertions;
  end
endmodule
