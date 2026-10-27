// #769: rejected only in SystemVerilog generations; 1364 mode keeps the legacy extension (see DISCOVERED_DEBT).
module proc_cont_var_select_1364_ext;
  reg [3:0] q;

  initial begin
    q = 4'h0;
    assign q[0] = 1'b1;
    #0;
    if (q[0] !== 1'b1) begin
      $display("FAILED default-mode assign extension");
      $finish;
    end
    force q[1] = 1'b1;
    #0;
    if (q[1] !== 1'b1) begin
      $display("FAILED default-mode force extension");
      $finish;
    end
    release q[1];
    deassign q[0];
    $display("PASSED");
  end
endmodule
