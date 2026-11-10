#ifndef IVL_PTimingCheck_H
#define IVL_PTimingCheck_H
/*
 * Copyright (c) 2006-2025 Stephen Williams <steve@icarus.com>
 *
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program; if not, write to the Free Software
 *    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

# include  "LineInfo.h"
# include  "PExpr.h"
# include  "pform_types.h"
# include  <memory>
# include  <string>

/*
* The PTimingCheck is the base class for all timing checks
*/
class PTimingCheck  : public LineInfo {

    public:
      enum EdgeType {EDGE_01, EDGE_0X, EDGE_10, EDGE_1X, EDGE_X0, EDGE_X1};

      struct event_t {
        pform_name_t name;
        bool posedge;
        bool negedge;
        std::vector<EdgeType> edges;
        std::unique_ptr<PExpr> condition;
      };

      // This struct is used to parse the optional arguments
      struct optional_args_t {
        pform_name_t* notifier          = nullptr;
        PExpr* timestamp_cond    = nullptr;
        PExpr* timecheck_cond    = nullptr;
        pform_name_t* delayed_reference = nullptr;
        pform_name_t* delayed_data      = nullptr;
        PExpr* event_based_flag         = nullptr;
        PExpr* remain_active_flag       = nullptr;
      };

      PTimingCheck() { }
      virtual ~PTimingCheck() override { }

      virtual void elaborate(class Design*des, class NetScope*scope) const = 0;

      virtual void dump(std::ostream&out, unsigned ind) const = 0;
};

/*
* The PRecRem is the parse of a $recrem timing check
*/
class PRecRem : public PTimingCheck {

    public:

      PRecRem(event_t* reference_event,
                    event_t* data_event,
                    PExpr* setup_limit,
                    PExpr* hold_limit,
                    pform_name_t* notifier,
                    PExpr* timestamp_cond,
                    PExpr* timecheck_cond,
                    pform_name_t* delayed_reference,
                    pform_name_t* delayed_data);

      ~PRecRem() override;

      void elaborate(class Design*des, class NetScope*scope) const override;

      void dump(std::ostream&out, unsigned ind) const override;

	// For the negative timing-check pass (IEEE 1800 31.9).
      const event_t& reference_event() const { return *reference_event_; }
      const event_t& data_event() const { return *data_event_; }
      const pform_name_t* delayed_reference() const { return delayed_reference_.get(); }
      const pform_name_t* delayed_data() const { return delayed_data_.get(); }

    private:
      std::unique_ptr<event_t> reference_event_;
      std::unique_ptr<event_t> data_event_;

      std::unique_ptr<PExpr> setup_limit_;
      std::unique_ptr<PExpr> hold_limit_;

      std::unique_ptr<pform_name_t> notifier_;

      std::unique_ptr<PExpr> timestamp_cond_;
      std::unique_ptr<PExpr> timecheck_cond_;

      std::unique_ptr<pform_name_t> delayed_reference_;
      std::unique_ptr<pform_name_t> delayed_data_;
};

/*
* The PSetupHold is the parse of a $setuphold timing check
*/
class PSetupHold : public PTimingCheck {

    public:
      PSetupHold(event_t* reference_event,
                    event_t* data_event,
                    PExpr* setup_limit,
                    PExpr* hold_limit,
                    pform_name_t* notifier,
                    PExpr* timestamp_cond,
                    PExpr* timecheck_cond,
                    pform_name_t* delayed_reference,
                    pform_name_t* delayed_data);

      ~PSetupHold() override;

      void elaborate(class Design*des, class NetScope*scope) const override;

      void dump(std::ostream&out, unsigned ind) const override;

	// For the negative timing-check pass (IEEE 1800 31.9).
      const event_t& reference_event() const { return *reference_event_; }
      const event_t& data_event() const { return *data_event_; }
      const pform_name_t* delayed_reference() const { return delayed_reference_.get(); }
      const pform_name_t* delayed_data() const { return delayed_data_.get(); }

    private:
      std::unique_ptr<event_t> reference_event_;
      std::unique_ptr<event_t> data_event_;

      std::unique_ptr<PExpr> setup_limit_;
      std::unique_ptr<PExpr> hold_limit_;

      std::unique_ptr<pform_name_t> notifier_;

      std::unique_ptr<PExpr> timestamp_cond_;
      std::unique_ptr<PExpr> timecheck_cond_;

      std::unique_ptr<pform_name_t> delayed_reference_;
      std::unique_ptr<pform_name_t> delayed_data_;
};

/* $width is elaborated after the event signal has a concrete packed shape,
   so vector events can be expanded into independent per-bit checks. */
class PWidth : public PTimingCheck {

    public:
      PWidth(const char*file, int line, unsigned lexical_pos,
             event_t* event, PExpr* limit, PExpr* threshold,
             pform_name_t* notifier);
      ~PWidth() override;
      void elaborate(class Design*des, class NetScope*scope) const override;
      void dump(std::ostream&out, unsigned ind) const override;

    private:
      std::unique_ptr<event_t> event_;
      std::unique_ptr<PExpr> limit_;
      std::unique_ptr<PExpr> threshold_;
      std::unique_ptr<pform_name_t> notifier_;
      std::string file_;
      unsigned lexical_pos_;
};

/* The PTchk is the identity of one timing-check directive. The checker
   itself is synthesized into processes while parsing; this record keeps
   what VPI (IEEE 1800-2017 37.38, 1800-2023 37.40) and SDF annotation
   (32.4.2) need: the check type, its reference and data terms, and the
   hidden variables the synthesized checker reads its limits from. It
   elaborates to a NetTchk of the instance scope. */
class PTchk : public PTimingCheck {

    public:
	// type is the IEEE 1800 Annex K vpiTchkType code. data may be
	// nullptr for the one-signal checks ($width, $period). The record
	// takes ownership of the events, the limit expressions and the
	// notifier.
      PTchk(int type, event_t*ref, event_t*data,
	    const std::vector<PExpr*>&limits,
	    const std::vector<perm_string>&limit_vars,
	    pform_name_t*notifier);
      ~PTchk() override;

      void elaborate(class Design*des, class NetScope*scope) const override;
      void dump(std::ostream&out, unsigned ind) const override;

      int type() const { return type_; }
      const event_t& ref() const { return *ref_; }
      const event_t* data() const { return data_.get(); }
      PExpr* limit(unsigned idx) const { return limits_[idx].get(); }
      unsigned limit_count() const { return limits_.size(); }

    private:
      int type_;
      std::unique_ptr<event_t> ref_;
      std::unique_ptr<event_t> data_;
      std::vector<std::unique_ptr<PExpr>> limits_;
      std::vector<perm_string> limit_vars_;
      std::unique_ptr<pform_name_t> notifier_;
};

#endif /* IVL_PTimingCheck_H */
