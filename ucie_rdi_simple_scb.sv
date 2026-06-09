`ifndef UCIE_RDI_SIMPLE_SCB_SV
`define UCIE_RDI_SIMPLE_SCB_SV

package ucie_rdi_simple_scb_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ucie_phy_pkg::*;

  typedef enum int {
    UCIE_RDI_SIMPLE_SIDE_A = 0,
    UCIE_RDI_SIMPLE_SIDE_B = 1
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

  `uvm_analysis_imp_decl(_simple_a)
  `uvm_analysis_imp_decl(_simple_b)

  class ucie_rdi_simple_scb extends uvm_component;
    `uvm_component_utils(ucie_rdi_simple_scb)

    uvm_analysis_imp_simple_a #(ucie_rdi_simple_flit, ucie_rdi_simple_scb) mon_a_export;
    uvm_analysis_imp_simple_b #(ucie_rdi_simple_flit, ucie_rdi_simple_scb) mon_b_export;

    ucie_rdi_simple_flit a_to_b_q[$];
    ucie_rdi_simple_flit b_to_a_q[$];
    int unsigned compare_count;
    int unsigned mismatch_count;
    int unsigned a_tx_count;
    int unsigned b_tx_count;
    int unsigned a_rx_count;
    int unsigned b_rx_count;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      mon_a_export = new("mon_a_export", this);
      mon_b_export = new("mon_b_export", this);
    endfunction

    function void write_simple_a(ucie_rdi_simple_flit item);
      ucie_rdi_simple_flit exp;

      if (item.dir == UCIE_RDI_SIMPLE_TX) begin
        a_tx_count++;
        a_to_b_q.push_back(item);
      end else begin
        a_rx_count++;
        if (b_to_a_q.size() == 0) begin
          mismatch_count++;
          `uvm_error("RDI_SIMPLE_SCB", {"Unexpected A RX: ", item.convert2string()})
        end else begin
          exp = b_to_a_q.pop_front();
          compare_flit("B_TX_TO_A_RX", exp, item);
        end
      end
    endfunction

    function void write_simple_b(ucie_rdi_simple_flit item);
      ucie_rdi_simple_flit exp;

      if (item.dir == UCIE_RDI_SIMPLE_TX) begin
        b_tx_count++;
        b_to_a_q.push_back(item);
      end else begin
        b_rx_count++;
        if (a_to_b_q.size() == 0) begin
          mismatch_count++;
          `uvm_error("RDI_SIMPLE_SCB", {"Unexpected B RX: ", item.convert2string()})
        end else begin
          exp = a_to_b_q.pop_front();
          compare_flit("A_TX_TO_B_RX", exp, item);
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
      if (a_to_b_q.size() != 0) begin
        mismatch_count += a_to_b_q.size();
        `uvm_error("RDI_SIMPLE_SCB",
                   $sformatf("%0d A->B expected flits were not received", a_to_b_q.size()))
      end
      if (b_to_a_q.size() != 0) begin
        mismatch_count += b_to_a_q.size();
        `uvm_error("RDI_SIMPLE_SCB",
                   $sformatf("%0d B->A expected flits were not received", b_to_a_q.size()))
      end
    endfunction

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info("RDI_SIMPLE_SCB",
                $sformatf("A_TX=%0d B_RX=%0d B_TX=%0d A_RX=%0d compares=%0d mismatches=%0d",
                          a_tx_count, b_rx_count, b_tx_count, a_rx_count,
                          compare_count, mismatch_count),
                UVM_LOW)
    endfunction
  endclass
endpackage

`endif
