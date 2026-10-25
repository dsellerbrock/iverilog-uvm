module top;
  logic [1:0][3:0] packed_var;

  initial begin
    integer fd;
    integer width;
    integer msb;
    integer lsb;
    integer found;
    reg [8*64-1:0] ident;
    reg [8*256-1:0] line;

    $dumpfile("sv_vcd_packed_range.vcd");
    $dumpvars(0, top);
    packed_var = 8'ha5;
    #1 $dumpflush;

    fd = $fopen("sv_vcd_packed_range.vcd", "r");
    if (!fd) $fatal(1, "could not read VCD");
    found = 0;
    while ($fgets(line, fd)) begin
      if ($sscanf(line, "$var reg %d %s packed_var [%d:%d]",
                  width, ident, msb, lsb) == 4) begin
        if (width == 8 && msb == 7 && lsb == 0)
          found = 1;
      end
    end
    $fclose(fd);
    if (!found) $fatal(1, "VCD packed variable range does not match its size");
    $display("PASS");
    $finish;
  end
endmodule
