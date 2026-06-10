`ifndef UCIE_RDI_SIMPLE_SCB_SV
`define UCIE_RDI_SIMPLE_SCB_SV

package ucie_rdi_simple_scb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ucie_phy_pkg::*;

  typedef enum int {
    UCIE_RDI_SIMPLE_US = 0,
    UCIE_RDI_SIMPLE_DS = 1
  } ucie_rdi_simple_side_e;

  typedef enum int {
    UCIE_RDI_SIMPLE_TX,
    UCIE_RDI_SIMPLE_RX
  } ucie_rdi_simple_dir_e;

  class ucie_rdi_simple_flit extends uvm_sequence_item;
    ucie_rdi_simple_side_e side;
    ucie_rdi_simple_dir_e  dir;
    time                   sample_time;
    ucie_rdi_state_e       pl_state_sts;
    bit [2:0]              pl_link_cfg;
    bit [2:0]              pl_speed_mode;
    bit [255:0]            data;
    bit [15:0]             user;
    bit                    sop;
    bit                    eop;

    `uvm_object_utils_begin(ucie_rdi_simple_flit)
      `uvm_field_enum(ucie_rdi_simple_side_e, side, UVM_DEFAULT)
      `uvm_field_enum(ucie_rdi_simple_dir_e, dir, UVM_DEFAULT)
      `uvm_field_enum(ucie_rdi_state_e, pl_state_sts, UVM_DEFAULT)
      `uvm_field_int(pl_link_cfg, UVM_DEFAULT)
      `uvm_field_int(pl_speed_mode, UVM_DEFAULT)
      `uvm_field_int(data, UVM_DEFAULT)
      `uvm_field_int(user, UVM_DEFAULT)
      `uvm_field_int(sop, UVM_DEFAULT)
      `uvm_field_int(eop, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "ucie_rdi_simple_flit");
      super.new(name);
    endfunction

    function string convert2string();
      return $sformatf("side=%0d dir=%0d sop=%0b eop=%0b user=0x%04h data=0x%064h time=%0t",
                       side, dir, sop, eop, user, data, sample_time);
    endfunction
  endclass

  `uvm_analysis_imp_decl(_simple_us)
  `uvm_analysis_imp_decl(_simple_ds)

  class ucie_rdi_simple_scb extends uvm_component;
    `uvm_component_utils(ucie_rdi_simple_scb)

    uvm_analysis_imp_simple_us #(ucie_rdi_simple_flit, ucie_rdi_simple_scb) us_export;
    uvm_analysis_imp_simple_ds #(ucie_rdi_simple_flit, ucie_rdi_simple_scb) ds_export;

    ucie_rdi_simple_flit us_to_ds_q[$];
    ucie_rdi_simple_flit ds_to_us_q[$];
    int unsigned compare_count;
    int unsigned mismatch_count;
    int unsigned us_tx_count;
    int unsigned ds_tx_count;
    int unsigned us_rx_count;
    int unsigned ds_rx_count;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      us_export = new("us_export", this);
      ds_export = new("ds_export", this);
    endfunction

    function void write_simple_us(ucie_rdi_simple_flit item);
      ucie_rdi_simple_flit exp;

      if (item.dir == UCIE_RDI_SIMPLE_TX) begin
        us_tx_count++;
        us_to_ds_q.push_back(item);
      end else begin
        us_rx_count++;
        if (ds_to_us_q.size() == 0) begin
          mismatch_count++;
          `uvm_error("RDI_SIMPLE_SCB", {"Unexpected US RX: ", item.convert2string()})
        end else begin
          exp = ds_to_us_q.pop_front();
          compare_flit("DS_TX_TO_US_RX", exp, item);
        end
      end
    endfunction

    function void write_simple_ds(ucie_rdi_simple_flit item);
      ucie_rdi_simple_flit exp;

      if (item.dir == UCIE_RDI_SIMPLE_TX) begin
        ds_tx_count++;
        ds_to_us_q.push_back(item);
      end else begin
        ds_rx_count++;
        if (us_to_ds_q.size() == 0) begin
          mismatch_count++;
          `uvm_error("RDI_SIMPLE_SCB", {"Unexpected DS RX: ", item.convert2string()})
        end else begin
          exp = us_to_ds_q.pop_front();
          compare_flit("US_TX_TO_DS_RX", exp, item);
        end
      end
    endfunction

    function void compare_flit(string path,
                               ucie_rdi_simple_flit exp,
                               ucie_rdi_simple_flit act);
      compare_count++;
      if ((exp.data !== act.data) ||
          (exp.user !== act.user) ||
          (exp.sop  !== act.sop)  ||
          (exp.eop  !== act.eop)) begin
        mismatch_count++;
        `uvm_error("RDI_SIMPLE_SCB",
                   $sformatf("%s mismatch\nEXP %s\nACT %s",
                             path, exp.convert2string(), act.convert2string()))
      end
    endfunction

    function void check_phase(uvm_phase phase);
      super.check_phase(phase);
      if (us_to_ds_q.size() != 0) begin
        mismatch_count += us_to_ds_q.size();
        `uvm_error("RDI_SIMPLE_SCB",
                   $sformatf("%0d US->DS expected flits were not received", us_to_ds_q.size()))
      end
      if (ds_to_us_q.size() != 0) begin
        mismatch_count += ds_to_us_q.size();
        `uvm_error("RDI_SIMPLE_SCB",
                   $sformatf("%0d DS->US expected flits were not received", ds_to_us_q.size()))
      end
    endfunction

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info("RDI_SIMPLE_SCB",
                $sformatf("US_TX=%0d DS_RX=%0d DS_TX=%0d US_RX=%0d compares=%0d mismatches=%0d",
                          us_tx_count, ds_rx_count, ds_tx_count, us_rx_count,
                          compare_count, mismatch_count),
                UVM_LOW)
    endfunction
  endclass
endpackage

`endif
