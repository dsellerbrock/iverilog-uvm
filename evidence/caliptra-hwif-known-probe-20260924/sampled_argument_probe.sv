module t;
  bit clk = 0;
  typedef struct packed {logic a; logic b;} hw_t;
  hw_t hwif_in;
  function automatic bit probe(input hw_t value);
    if ($isunknown(value)) $display("HWIF_PROBE property_arg=%b", value);
    return 1'b1;
  endfunction
  initial begin
    hwif_in = 2'b1x;
    #1 clk = 1;
       hwif_in <= 2'b11;
    #1 $finish;
  end
  ERR_HWIF_IN: assert property (@(posedge clk)
    disable iff ((!hwif_in.a) !== 0) (!$isunknown(hwif_in)))
    else begin
      $display("HWIF_PROBE action_live=%b", hwif_in);
      $fatal(1, "ERR_HWIF_IN");
    end
  ERR_HWIF_IN_PROBE: assert property (@(posedge clk)
    disable iff ((!hwif_in.a) !== 0) (probe(hwif_in)));
endmodule
