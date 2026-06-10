`ifndef UCIE_RDI_SIMPLE_AGENT_PKG_SV
`define UCIE_RDI_SIMPLE_AGENT_PKG_SV

package ucie_rdi_simple_agent_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import ucie_phy_pkg::*;
  import ucie_rdi_simple_item_pkg::*;

  class ucie_rdi_simple_sequencer extends uvm_sequencer #(ucie_rdi_simple_seq_item);
    `uvm_component_utils(ucie_rdi_simple_sequencer)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class ucie_rdi_simple_driver extends uvm_driver #(ucie_rdi_simple_seq_item);
    `uvm_component_utils(ucie_rdi_simple_driver)
    svt_ucie_d2d_vif rdi_vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(svt_ucie_d2d_vif)::get(this, "", "rdi_vif", rdi_vif))
        `uvm_fatal("RDI_SIMPLE_DRV", "Missing rdi_vif")
    endfunction

    task run_phase(uvm_phase phase);
      forever begin
        seq_item_port.get_next_item(req);
        drive_item(req);
        seq_item_port.item_done();
      end
    endtask

    task drive_item(ucie_rdi_simple_seq_item item);
      wait (!rdi_vif.reset);
      while (!((rdi_vif.pl_state_sts == RDI_ACTIVE) && rdi_vif.pl_inband_pres)) begin
        @(posedge rdi_vif.lclk);
      end

      @(posedge rdi_vif.lclk);
      rdi_vif.lp_data <= item.data;
      rdi_vif.lp_valid <= 1'b1;
      rdi_vif.lp_irdy <= 1'b1;

      do begin
        @(posedge rdi_vif.lclk);
      end while (!rdi_vif.pl_trdy);

      rdi_vif.lp_valid <= 1'b0;
      rdi_vif.lp_irdy <= 1'b0;
      rdi_vif.lp_data <= '0;
    endtask
  endclass
endpackage

`endif
