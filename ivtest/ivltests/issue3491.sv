// IEEE 1800-2017/2023 10.6.2 and 28.16.2: forcing a tran island
// changes its visible values without changing the charge it stores.
`timescale 1ns/1ps

module issue3491_source(input en, input d, output y);
  bufif1 (y, d, en);
endmodule

module issue3491_load(inout a, output y);
  trireg cap;
  tran (cap, a);
  assign y = cap;
endmodule

module issue3491;
  int errors = 0;

  task automatic check(input string what, got, expected);
    if (got != expected) begin
      $error("%s t=%0t: got %s, expected %s", what, $time, got, expected);
      errors++;
    end
  endtask

  logic drive = 1;
  trireg alone, cap;
  trireg #(0,0,6) timed_alone, timed_cap, timed_quick;
  wire peer, timed_peer, quick_peer;
  wire quick_reader = timed_quick ^ 1'b0;
  bufif1 (alone, 1'b1, drive), (cap, 1'b1, drive),
         (timed_alone, 1'b1, drive), (timed_cap, 1'b1, drive),
         (timed_quick, 1'b1, drive);
  tran (cap, peer), (timed_cap, timed_peer), (timed_quick, quick_peer);

  logic remote_drive = 0;
  trireg recharged;
  wire remote;
  bufif1 (recharged, 1'b1, drive), (remote, 1'b0, remote_drive);
  tran (recharged, remote);

  trireg [3:0] vector_cap;
  wire [1:0] slice_peer;
  bufif1 vec_drv[3:0] (vector_cap, 4'b1011, drive);
  tran slice_link[1:0] (vector_cap[2:1], slice_peer);

  initial begin
    #1;
    check("driven through tran", $sformatf("%v", peer), "St1");
    #1 drive = 0;

    #2;
    check("standalone charge", $sformatf("%v", alone), "Me1");
    check("island charge", $sformatf("%v", cap), "Me1");
    check("charge through tran", $sformatf("%v", peer), "Me1");
    force alone = 0;
    force cap = 0;
    force timed_alone = 0;
    force timed_cap = 0;

    // This pair finishes before the deferred island event. The raw
    // island output can compare equal and still need to be republished.
    force timed_quick = 0;
    check("quick force", $sformatf("%v", timed_quick), "St0");
    release timed_quick;
    check("quick release", $sformatf("%v", timed_quick), "Me1");
    #0 check("quick release reaches fan-out", $sformatf("%b", quick_reader), "1");

    // A real remote driver must recharge the capacitor under a force.
    force recharged = 1;
    remote_drive = 1;
    force vector_cap[2:1] = 2'b10;
    #1;
    check("forced standalone", $sformatf("%v", alone), "St0");
    check("forced capacitor", $sformatf("%v", cap), "St0");
    check("force through tran", $sformatf("%v", peer), "St0");
    check("vector force", $sformatf("%b", vector_cap), "1101");
    check("force through slice", $sformatf("%b", slice_peer), "10");
    check("force during real drive", $sformatf("%v", recharged), "St1");

    remote_drive = 0;
    release vector_cap[1];
    check("partial release", $sformatf("%b", vector_cap), "1111");
    check("released bit strength", $sformatf("%v", vector_cap[1]), "Me1");
    check("remaining force", $sformatf("%v", vector_cap[2]), "St1");
    #1;
    check("partial release through slice", $sformatf("%b", slice_peer), "11");
    release vector_cap[2];
    check("second bit release", $sformatf("%b", vector_cap), "1011");
    release recharged;
    check("real charge after remote driver went off",
          $sformatf("%v", recharged), "Me0");

    #1.999;
    check("quick release before original decay", $sformatf("%v", timed_quick), "Me1");
    #0.002;
    check("quick release after original decay", $sformatf("%v", timed_quick), "MeX");
    check("force visible across decay", $sformatf("%v", timed_peer), "St0");

    #3.999;
    release alone;
    release cap;
    release timed_alone;
    release timed_cap;
    check("released standalone", $sformatf("%v", alone), "Me1");
    check("immediate island release", $sformatf("%v", cap), "Me1");
    check("standalone decay under force", $sformatf("%v", timed_alone), "MeX");
    check("island decay under force", $sformatf("%v", timed_cap), "MeX");
    #1;
    check("release through tran", $sformatf("%v", peer), "Me1");
    check("decay revealed through tran", $sformatf("%v", timed_peer), "MeX");
  end

  // A force on the control can close a switch. Its real driver, 0,
  // then reaches the trireg in the charge traversal.
  trireg controlled_cap;
  wire control = 1'b0;
  bufif1 (controlled_cap, 1'b1, drive);
  tranif1 (controlled_cap, control, control);

  initial begin
    #4;
    check("switch initially off", $sformatf("%v", controlled_cap), "Me1");
    force control = 1;
    #1 check("force enables switch", $sformatf("%v", controlled_cap), "St1");
    release control;
    check("released switch control", $sformatf("%v", control), "St0");
    check("charge through forced switch", $sformatf("%v", controlled_cap), "Me0");
  end

  // The force and real drive take the same annotated time to cross the
  // boundary, but only the real drive may change the retained charge.
  logic sdf_en = 1, sdf_d = 1;
  wire link, seen;
  issue3491_source src(sdf_en, sdf_d, link);
  issue3491_load load(link, seen);

  initial begin
    $sdf_annotate("ivltests/issue3491.sdf", issue3491);
    #10 sdf_en = 0;
    #2 check("pending delayed turnoff", $sformatf("%v", load.cap), "St1");
    #2 check("charge after delayed turnoff", $sformatf("%v", load.cap), "Me1");

    force link = 0;
    #2 check("pending delayed force", $sformatf("%v", load.cap), "Me1");
    #2 check("force after annotated delay", $sformatf("%b", seen), "0");
    release link;
    #2 check("pending delayed release", $sformatf("%b", seen), "0");
    #2 check("charge after delayed release", $sformatf("%v", load.cap), "Me1");

    sdf_d = 0;
    sdf_en = 1;
    #2 check("pending real delayed drive", $sformatf("%v", load.cap), "Me1");
    #2 check("real drive after annotated delay", $sformatf("%v", load.cap), "St0");
    sdf_en = 0;
    #4 check("new charge after real delayed drive", $sformatf("%v", load.cap), "Me0");

    if (errors != 0)
      $fatal(1, "%0d charge checks failed", errors);
    $display("PASSED");
  end
endmodule
