// An active out-of-range four-state packed word read must fail and roll back.
typedef struct packed { logic [1:0][7:0] seeds; } words_t;
typedef struct packed { logic [-1:-2][7:0] seeds; } negative_words_t;
module test;
  words_t words, saved;
  negative_words_t negative_words, negative_saved;
  int signed_idx;
  longint unsigned high_idx;
  bit [1:0] random_idx;
  initial begin
    words.seeds[0] = 8'h12;
    words.seeds[1] = 8'h34;
    saved = words;
    signed_idx = -1;
    if (std::randomize(words) with {
      words.seeds[signed_idx] inside {0, '1};
    }) $fatal(1, "negative index accepted");
    if (words !== saved) $fatal(1, "negative index mutated target");

    high_idx = '1;
    if (std::randomize(words) with {
      words.seeds[high_idx] == 8'h00;
    }) $fatal(1, "high unsigned index accepted");
    if (words !== saved) $fatal(1, "high index mutated target");

    negative_words.seeds[-1] = 8'h56;
    negative_words.seeds[-2] = 8'h78;
    negative_saved = negative_words;
    if (std::randomize(negative_words) with {
      negative_words.seeds[high_idx] == 8'h00;
    }) $fatal(1, "unsigned high index aliased negative label");
    if (negative_words !== negative_saved)
      $fatal(1, "negative range invalid read mutated target");

    random_idx = 1;
    if (std::randomize(words, random_idx) with {
      random_idx == 2;
      words.seeds[random_idx] == 8'h00;
    }) $fatal(1, "randomized invalid index accepted");
    if (words !== saved || random_idx != 1)
      $fatal(1, "randomized invalid index mutated targets");
    $display("PASSED");
  end
endmodule
