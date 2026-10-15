// Issue #434: detached children retain automatic aggregate handle values.
class detached_aggregate_tag;
  int id;
endclass

interface detached_aggregate_if;
  int marker;
endinterface

typedef struct {
  detached_aggregate_tag handle;
  int id;
} detached_class_capture_t;

typedef struct {
  virtual detached_aggregate_if vif;
  int id;
} detached_vif_capture_t;

module sv_detached_aggregate_handles;
  detached_aggregate_if vif0(), vif1();
  int class_seen11 = 0;
  int class_seen22 = 0;
  int vif_seen33 = 0;
  int vif_seen44 = 0;

  task automatic launch_class(input detached_class_capture_t rec);
    fork begin
      #1;
      if (rec.handle == null || rec.handle.id != rec.id)
        $fatal(1, "detached class aggregate changed: id=%0d", rec.id);
      if (rec.id == 11) class_seen11++;
      else if (rec.id == 22) class_seen22++;
      else $fatal(1, "unexpected class aggregate id %0d", rec.id);
    end join_none
  endtask

  task automatic launch_vif(input detached_vif_capture_t rec);
    fork begin
      #1;
      if (rec.vif == null || rec.vif.marker != rec.id)
        $fatal(1, "detached VIF aggregate changed: id=%0d", rec.id);
      if (rec.id == 33) vif_seen33++;
      else if (rec.id == 44) vif_seen44++;
      else $fatal(1, "unexpected VIF aggregate id %0d", rec.id);
    end join_none
  endtask

  initial begin
    detached_aggregate_tag first, second;
    detached_class_capture_t class_rec;
    detached_vif_capture_t vif_rec;

    first = new;
    first.id = 11;
    second = new;
    second.id = 22;
    class_rec.handle = first;
    class_rec.id = 11;
    launch_class(class_rec);
    class_rec.handle = second;
    class_rec.id = 22;
    launch_class(class_rec);
    class_rec.handle = null;
    class_rec.id = 99;

    vif0.marker = 33;
    vif1.marker = 44;
    vif_rec.vif = vif0;
    vif_rec.id = 33;
    launch_vif(vif_rec);
    vif_rec.vif = vif1;
    vif_rec.id = 44;
    launch_vif(vif_rec);
    vif_rec.vif = null;
    vif_rec.id = 99;

    #2;
    if (class_seen11 != 1 || class_seen22 != 1 ||
        vif_seen33 != 1 || vif_seen44 != 1)
      $fatal(1, "detached aggregate worker counts are wrong");
    $display("PASSED");
  end
endmodule
