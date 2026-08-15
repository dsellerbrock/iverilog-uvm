// Reduced from sv-tests c4229f3 tests/chapter-21/21.7--dumpports.sv.
// It preserves the corpus call forms and makes runtime completion observable.
module sv_dumpports_svtests_21_7;
  integer i;
  string fname = "work/sv_dumpports_svtests_21_7.evcd";

  initial begin
    $dumpports(sv_dumpports_svtests_21_7, fname);
    $dumpportslimit(1024*1024, fname);

    i = 1;
    #100 i = 2;
    #200 $dumpportsoff(fname);
    i = 3;
    #800 $dumpportson(fname);
    i = 4;
    #100 $dumpportsflush(fname);
    i = 5;
    #300 begin
      $dumpportsall(fname);
      i = 6;
      $display("PASSED");
    end
  end
endmodule
