// IEEE 1800-2017/2023 10.10: an unpacked-array concatenation item must
// either be assignment-compatible with the destination element type or be
// an unpacked collection whose element type is assignment-compatible with
// that destination element. Selecting through all three queue dimensions
// leaves a scalar real, which satisfies neither rule for a darray<real>
// destination element. An associative-array item with a different index
// type is likewise not assignment-compatible and is never a positional
// collection.
module sv_unpacked_concat_nested_scalar_fail;
  typedef int aa_string_t[string];
  typedef int aa_int_t[int];

  real deep_source[$][$][$];
  real queue_of_darrays[$][];
  aa_string_t queue_of_string_maps[$];
  aa_int_t int_map;
  aa_int_t associative_target;

  initial begin
    queue_of_darrays = {deep_source[1][0][0]};
    queue_of_string_maps = {int_map};
    associative_target = {1, 2};
  end
endmodule
