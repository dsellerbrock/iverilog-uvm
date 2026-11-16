// IEEE 1800-2017/2023 26.2: a package shall not refer to items defined in
// the compilation-unit scope, including a compilation-unit typedef.
typedef logic [3:0] cu_t;
package p; cu_t t = 4'h9; endpackage
module t; initial $display("t=%0d", p::t); endmodule
