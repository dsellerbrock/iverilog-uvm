// IEEE 1800-2017/2023 26.2: a package shall not refer to items defined in
// the compilation-unit scope. Package r imports a same-named item from
// package q, which is legal; package p falls back to the unit's cu.
int cu = 1;
package q; int cu = 2; endpackage
package r; import q::cu; int z = cu; endpackage
package p; int y = cu; endpackage
module t; initial $display("y=%0d z=%0d", p::y, r::z); endmodule
