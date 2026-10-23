module sv_vcd_event_checkpoint_dut;
  event ev;
  initial #5 -> ev;
endmodule

module sv_vcd_event_checkpoint;
  sv_vcd_event_checkpoint_dut dut();

  initial begin
    integer fd;
    integer status;
    integer markers;
    reg [8*256-1:0] line;
    reg [7:0] marker_id;

    $dumpfile("work/sv_vcd_event_checkpoint.vcd");
    $dumpvars(0, dut);
    #10 $dumpoff;
    #5 $dumpon;
    #5 $dumpall;
    #5;

    $dumpflush;
    fd = $fopen("work/sv_vcd_event_checkpoint.vcd", "r");
    if (fd == 0) $fatal(1, "could not open VCD output");
    markers = 0;
    while ($fgets(line, fd)) begin
      status = $sscanf(line, "1%c", marker_id);
      if (status == 1 && marker_id == "!") markers = markers + 1;
    end
    $fclose(fd);

    if (markers != 1)
      $fatal(1, "expected one event marker, found %0d", markers);
    $display("PASSED");
    $finish;
  end
endmodule
