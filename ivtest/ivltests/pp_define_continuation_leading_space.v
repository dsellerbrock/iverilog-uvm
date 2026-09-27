// Leading white space is not part of a macro's text (IEEE 1800-2017/2023
// 22.5.1), including indentation on a continuation line that begins the
// body. OpenTitan stringifies such a body into a UVM HDL path
// (rom_ctrl/sram_ctrl tb: `define ROM_CTRL_MEM_HIER \ <newline> tb.dut...);
// the kept indentation made the backdoor path invalid.
`define STRINGIFY(x) `"x`"
`define HIER \
    tb.dut.mem
`define HIER2   tb.dut.mem2
`define HIER3 \
	\
    tb.dut.mem3
`define ADD(a, b) \
    ((a) + \
     (b))
`define EMPTY \

module test;
  string a, b, c;
  int s;
  initial begin
    a = `STRINGIFY(`HIER);
    b = `STRINGIFY(`HIER2);
    c = `STRINGIFY(`HIER3);
    s = `ADD(2, 3) `EMPTY;
    if (a == "tb.dut.mem" && b == "tb.dut.mem2" && c == "tb.dut.mem3" && s == 5) $display("PASSED");
    else $display("FAILED '%s' '%s' '%s' %0d", a, b, c, s);
  end
endmodule
