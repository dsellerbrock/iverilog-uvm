module top;
  event ev;
  reg a = 0;

  initial begin : check_vcd
    integer fd;
    integer width;
    integer found;
    reg [8*64-1:0] ident;
    reg [8*256-1:0] line;

    $dumpfile("sv_vcd_unused_event.vcd");
    $dumpvars(0, top);
    #1 a = 1;
    $dumpflush;

    fd = $fopen("sv_vcd_unused_event.vcd", "r");
    if (!fd) $fatal(1, "could not read VCD");
    found = 0;
    while ($fgets(line, fd)) begin
      if ($sscanf(line, "$var event %d %s ev", width, ident) == 2)
        found = 1;
    end
    $fclose(fd);
    if (!found) $fatal(1, "VCD omitted unused event ev");
    $display("PASS");
    $finish;
  end
endmodule
