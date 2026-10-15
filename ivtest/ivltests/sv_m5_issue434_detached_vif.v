// IEEE 1800-2017/2023 §§9.3.2, 13.3, 25.9; issue #434.
interface issue434_if;
  int id;
endinterface

typedef struct {
  virtual issue434_if vif;
  int id;
} issue434_if_capture_t;

module issue434_interface;
  issue434_if if11();
  issue434_if if22();
  int seen11;
  int seen22;

  task automatic launch(input issue434_if_capture_t rec);
    fork
      begin
        #1;
        if (rec.vif == null || rec.vif.id != rec.id)
          $fatal(1, "captured interface aggregate changed: id=%0d", rec.id);
        if (rec.id == 11)
          seen11++;
        else if (rec.id == 22)
          seen22++;
        else
          $fatal(1, "unexpected captured id %0d", rec.id);
      end
    join_none
  endtask

  initial begin
    issue434_if_capture_t rec;
    if11.id = 11;
    if22.id = 22;
    rec.vif = if11; rec.id = 11;
    launch(rec);
    rec.vif = if22; rec.id = 22;
    launch(rec);
    rec.vif = null; rec.id = 99;
    #2;
    if (seen11 != 1 || seen22 != 1)
      $fatal(1, "captured interface aggregate counts %0d/%0d", seen11, seen22);
    $display("PASS: detached workers retained aggregate VIF handles");
    $display("PASSED");
  end
endmodule
