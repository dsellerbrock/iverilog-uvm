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
    entry = logs["sw"][8];
    entry.arg[1] = 8'hfe;
    logs["sw"][8] = entry;
    entry = logs["sw"][8];
    if (entry.arg[1] !== 8'hfe) $fatal(1, "write lost");
    $display("PASS copied nested AA dynamic write");
  end
endmodule
