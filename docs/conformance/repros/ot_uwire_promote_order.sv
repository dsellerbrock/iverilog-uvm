// Reproducer: a legal disjoint-element mixed drive is rejected when the
// procedural driver sits inside a GENERATE block.
//
//   data_state[0]   is driven by a continuous assign
//   data_state[r+1] is driven procedurally, from inside a generate loop
//
// Different elements of one packed array, so IEEE 1800-2017 6.5 permits
// it -- the prohibition is on mixing drivers on the SAME bits. Written
// WITHOUT the generate (both drivers at module level, in either textual
// order) the identical design is accepted, so the rejection tracks
// elaboration order rather than semantics.
//
// The var->uwire promotion in elab_net.cc gives up when
// sig->peek_lref() != 0 -- a whole-signal count of procedural l-values,
// with no bit information. A generate block's processes register their
// l-values before the module-level continuous assign is elaborated, so
// the promotion is refused and the assign is reported as driving a
// variable. The bit-accurate disjointness test exists only on the
// continuous side (lref_mask_ / test_part_driven).
//
// Reached in OpenTitan at prim_subst_perm.sv:35 and prim_prince.sv:190.
module sp #(parameter int DW = 8, parameter int NR = 3, parameter bit Dec = 0)
  (input [DW-1:0] data_i, input [DW-1:0] key_i, output logic [DW-1:0] data_o);
  logic [NR:0][DW-1:0] data_state;
  assign data_state[0] = data_i;
  for (genvar r = 0; r < NR; r++) begin : gen_round
    logic [DW-1:0] sbox;
    if (Dec) begin : gen_dec
      always_comb begin : p_dec
        sbox = data_state[r] ^ key_i;
        data_state[r + 1] = sbox;
      end
    end else begin : gen_enc
      always_comb begin : p_enc
        sbox = data_state[r] ^ key_i;
        data_state[r + 1] = sbox;
      end
    end
  end
  assign data_o = data_state[NR] ^ key_i;
endmodule
module top;
  logic [7:0] a, k, o;
  sp #(.DW(8), .NR(3), .Dec(0)) u(.data_i(a), .key_i(k), .data_o(o));
endmodule
