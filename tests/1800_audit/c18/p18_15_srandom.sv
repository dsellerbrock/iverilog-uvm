// IEEE 1800-2017 §18.15 / IEEE 1800-2023 §18.15
// Manually seeding randomize with srandom()
class Packet;
  rand bit [15:0] header;
  function new(int seed = 0);
    if (seed != 0)
      this.srandom(seed);
  endfunction
endclass

module test;
  initial begin
    Packet p1, p2, p3;
    bit [15:0] seq1 [5];
    bit [15:0] seq2 [5];
    int unsigned dummy;

    // Internal seeding in new().
    p1 = new(100);
    p2 = new(100);
    for (int i = 0; i < 5; i++) begin
      void'(p1.randomize());
      void'(p2.randomize());
      seq1[i] = p1.header;
      seq2[i] = p2.header;
      if (seq1[i] !== seq2[i])
        $fatal(1, "Internal srandom(100) mismatch at step %0d: %h vs %h", i, seq1[i], seq2[i]);
    end

    // External re-seeding restores the same sequence.
    p1.srandom(100);
    for (int i = 0; i < 5; i++) begin
      void'(p1.randomize());
      if (p1.header !== seq1[i])
        $fatal(1, "External p1.srandom(100) did not reproduce sequence at step %0d", i);
    end

    // Object RNG isolation: unrelated randomness must not perturb p2.
    p1.srandom(200);
    void'(p1.randomize());
    seq1[0] = p1.header;
    void'(p1.randomize());
    seq1[1] = p1.header;

    p2.srandom(200);
    void'(p2.randomize());
    dummy = $urandom();
    p3 = new(999);
    void'(p3.randomize());
    void'(p2.randomize());
    if (p2.header !== seq1[1])
      $fatal(1, "Object RNG was perturbed by intervening thread/object randomization");

    // Seed 0 is legal and reproducible.
    p1.srandom(0);
    void'(p1.randomize());
    seq1[0] = p1.header;
    p2.srandom(0);
    void'(p2.randomize());
    if (p2.header !== seq1[0])
      $fatal(1, "srandom(0) repeatability failed");

    $display("PASS srandom clause 18.15");
  end
endmodule
