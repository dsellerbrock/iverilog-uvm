module top;
  typedef struct {
    int nargs;
    bit [7:0] arg[];
  } log_t;
  log_t logs[string][int];
  initial begin
    log_t entry;
    entry.nargs = 2;
    entry.arg = new[2];
    logs["sw"][8] = entry;
    logs["sw"][8].arg[1] = 8'hfe;
    if (logs["sw"][8].arg[1] !== 8'hfe) $fatal(1, "write lost");
    $display("PASS direct nested AA dynamic write");
  end
endmodule
