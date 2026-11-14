module issue2873_child;
  task automatic reports;
    unique case (2) 0: ; 1: ; endcase
    unique0 case (0) 0: ; 0: ; endcase
    priority if (0) ; else if (0) ;
    unique if (1) ; else if (1) ;
    unique0 if (1) ; else if (1) ;
    priority case (2) 0: ; 1: ; endcase
    unique if (0) ; else if (0) ;
  endtask
endmodule

module issue2873_violation_control;
  issue2873_child a(), b();
  task automatic both(string tag);
    $display("%0t %s", $time, tag);
    a.reports();
    b.reports();
  endtask
  initial begin
    #1 both("initial");
    $assertoff;
    #1 both("assertoff");
    $assertcontrol(4, 32, 0, 0, a);
    $assertcontrol(4, 64, 0, 0, b);
    #1 both("scoped off");
    $assertcontrol(1, 224, 0, 0, a);
    $assertcontrol(4, 224);
    #1 both("locked a");
    $assertcontrol(2, 224, 0, 0, a);
    $assertcontrol(3, 224);
    $assertcontrol(9, 224);
    #1 both("actions unchanged");
    #1 both("scoped kill queued");
    $assertcontrol(5, 32, 0, 0, a);
    $assertcontrol(3, 32, 0, 0, a);
    #1 both("off keeps queued");
    $assertcontrol(4, 224);
    #1 both("off prevents queue");
    $assertcontrol(3, 224);
    #1 both("kill flushes queued");
    $assertcontrol(5, 224);
    $assertcontrol(3, 224);
    #1 both("re-enabled");
    #1 $finish;
  end
endmodule
