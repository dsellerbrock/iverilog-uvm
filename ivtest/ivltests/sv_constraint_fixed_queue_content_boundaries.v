class C;
  rand logic [3:0] q[2][2][$];
  int posts;
  constraint c {
    foreach (q[i,j]) q[i][j].size() == 2;
    q[1][1][0] == 4'h5;
  }
  function void post_randomize(); posts++; endfunction
  function int draw_selected();
    return this.randomize(q) with { q[1][0][1] == 4'h7; };
  endfunction
endclass
class C_index_guard;
  rand bit [3:0] q[1][1][$];
  constraint c { q[0][0].size() == 1; q[0][0][0] == 4'h2; }
endclass
module test;
  C c;
  C_index_guard index_guard;
  logic [31:0] unknown_index;
  logic [3:0] prior[2][2][2];
  task automatic snapshot;
    foreach (prior[i,j,k]) prior[i][j][k] = c.q[i][j][k];
  endtask
  task automatic unchanged;
    foreach (prior[i,j,k])
      if (c.q[i][j][k] !== prior[i][j][k])
        $fatal(1, "rollback content changed at %0d %0d %0d", i,j,k);
  endtask
  initial begin
    int posts;
    c = new;
    if (!c.randomize()) $fatal(1, "setup failed");
    snapshot(); posts = c.posts;
    if (c.randomize() with { q[1][1][2] == 4'h3; })
      $fatal(1, "OOB selected element accepted");
    unchanged();
    if (c.posts != posts) $fatal(1, "OOB post_randomize");
    if (c.randomize() with { q[1][1][0] == 4'h6; })
      $fatal(1, "contradiction accepted");
    unchanged();
    if (c.posts != posts) $fatal(1, "contradiction post_randomize");

    c.q[0][0] = '{4'h5, 4'h6};
    c.q[0][0].rand_mode(0);
    if (!c.randomize() with { q[0][0][0] == 4'h5; })
      $fatal(1, "disabled leaf matching state failed");
    if (c.q[0][0][0] !== 4'h5 || c.q[0][0][1] !== 4'h6)
      $fatal(1, "disabled leaf changed");
    c.q[0][0][0] = 4'h4;
    snapshot(); posts = c.posts;
    if (c.randomize() with { q[0][0][0] == 4'h5; })
      $fatal(1, "disabled leaf mismatch accepted");
    unchanged();
    if (c.posts != posts) $fatal(1, "disabled leaf post_randomize");

    c.q[1][0][1] = 4'h9;
    c.q[1][0][1].rand_mode(0);
    if (!c.randomize() with { q[1][0][1] == 4'h9; })
      $fatal(1, "disabled element matching state failed");
    if (c.q[1][0][1] !== 4'h9)
      $fatal(1, "disabled element changed");
    c.q[1][0][1] = 4'hx;
    snapshot(); posts = c.posts;
    if (c.randomize() with { q[1][0][1] == 4'h0; })
      $fatal(1, "disabled X element accepted");
    unchanged();
    if (c.posts != posts) $fatal(1, "disabled X post_randomize");
    c.q[1][0][1] = 4'hz;
    snapshot(); posts = c.posts;
    if (c.randomize() with { q[1][0][1] == 4'h0; })
      $fatal(1, "disabled Z element accepted");
    unchanged();
    if (c.posts != posts) $fatal(1, "disabled Z post_randomize");
    if (!c.draw_selected() || c.q[1][0][1] !== 4'h7)
      $fatal(1, "explicit selection failed to override element rand_mode");
    unknown_index = 'x;
    index_guard = new;
    index_guard.q[0][0] = '{4'h1};
    index_guard.q[unknown_index][0][0].rand_mode(0);
    if (!index_guard.randomize() || index_guard.q[0][0][0] !== 4'h2)
      $fatal(1, "unknown fixed leaf disabled queue element zero");
    index_guard = new;
    index_guard.q[0][0] = '{4'h1};
    index_guard.q[0][0][unknown_index].rand_mode(0);
    if (!index_guard.randomize() || index_guard.q[0][0][0] !== 4'h2)
      $fatal(1, "unknown queue index disabled element zero");
    $display("PASSED");
  end
endmodule
