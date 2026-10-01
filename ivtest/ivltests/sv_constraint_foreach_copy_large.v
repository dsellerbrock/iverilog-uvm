// foreach (dst[i]) dst[i] == src[i] over a few hundred elements, in both a
// std::randomize() with-clause and a class constraint (IEEE 1800-2017/2023
// 18.5.8, 18.7). Every element of the source queue used to be expanded into
// each destination element's selection, and every pinned element took a
// diversity objective, so 200 elements ran for minutes (OpenTitan spi_device).
class copier;
  rand bit [7:0] dst[$];
  int src[$];
  constraint c_copy {
    dst.size() == src.size();
    foreach (dst[i]) dst[i] == src[i][7:0];
  }
endclass

module main;
  int errors;
  localparam int N = 400;
  initial begin
    int src[$];
    bit [7:0] dst[$];
    copier c;
    c = new;
    for (int i = 0; i < N; i++) src.push_back((i * 37) % 251);

    if (!std::randomize(dst) with {
          dst.size() == N;
          foreach (dst[i]) dst[i] == src[i];
        }) begin
      $display("FAILED std::randomize"); errors++;
    end
    if (dst.size() != N) begin $display("FAILED size %0d", dst.size()); errors++; end
    foreach (dst[i]) if (dst[i] !== src[i][7:0]) begin
      $display("FAILED dst[%0d]=%0d", i, dst[i]); errors++;
    end

    c.src = src;
    if (!c.randomize()) begin $display("FAILED class randomize"); errors++; end
    if (c.dst.size() != N) begin $display("FAILED class size %0d", c.dst.size()); errors++; end
    foreach (c.dst[i]) if (c.dst[i] !== src[i][7:0]) begin
      $display("FAILED c.dst[%0d]=%0d", i, c.dst[i]); errors++;
    end
    if (errors == 0) $display("PASSED");
  end
endmodule
