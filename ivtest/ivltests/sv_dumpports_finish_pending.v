module dumpports_finish_leaf(input wire value);
endmodule

module sv_dumpports_finish_pending;
  reg value = 0;
  dumpports_finish_leaf dut(value);
  initial begin
    $dumpports(dut, "work/sv_dumpports_finish_pending.evcd");
    #1 begin
      value = 1;
      $finish;
    end
  end
endmodule
