// M13 negative: bind whose target module is not defined anywhere
// must be a loud error, not a silent drop (manifesto principle 4).
module chk(input logic c); endmodule
bind no_such_module chk c1(.c(c));
module top; initial $finish(0); endmodule
