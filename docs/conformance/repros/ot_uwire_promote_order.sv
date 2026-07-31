// Reproducer: legal disjoint-element mixed drive rejected only when a
// conditional generate nested in a loop generate elaborates the
// procedural driver before the module-level continuous assign.
// data_state[0] is driven continuously; data_state[r+1] procedurally.
// IEEE 1800-2017 6.5 forbids mixing drivers on the SAME bits only.
// Removing the if/else (keeping one always_comb) makes this compile.
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
