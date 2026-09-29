module top;
  typedef struct {
    int nargs;
    bit [31:0] str_arg_idx;
  } log_t;
  log_t logs[string][int];
  initial begin
    string name;
    int addr;
    int i;
    bit [31:0] str_arg_idx;
    name = "sw";
    addr = 8;
    i = 1;
    logs[name][addr] = '{nargs: 2, str_arg_idx: 32'h2};
    str_arg_idx = logs[name][addr].str_arg_idx;
    if (!str_arg_idx[i]) $fatal(1, "missing string index");
    $display("PASS nested AA struct bit-select alias");
  end
endmodule
