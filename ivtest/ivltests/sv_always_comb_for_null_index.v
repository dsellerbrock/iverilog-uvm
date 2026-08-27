// A for_initialization that declares SEVERAL control variables has no single
// index variable, so NetForLoop::index_ is null. Two synthesis-side consumers
// dereferenced it unconditionally and segfaulted:
//
//   - NetForLoop::check_synth, through print_for_idx_warning's idx->name();
//   - NetForLoop::nex_input, through index_->pin_count() while always_comb
//     built its implicit sensitivity list.
//
// NetForLoop::synth_async already rejected the same case with a `sorry'.
// This must report that the loop is not synthesizable and exit nonzero,
// never signal.
module sv_always_comb_for_null_index(input logic [3:0] a, output logic [3:0] y);
  always_comb begin
    y = 4'b0;
    for (int i = 0, byte j = 1; i < 4; i++)
      y[i] = a[3-i] & j[0];
  end
endmodule
