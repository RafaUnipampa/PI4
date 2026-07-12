`timescale 1ns/1ps

module qlearning_system_8way #(
    parameter Q_WIDTH     = 32,
    parameter STATE_WIDTH = 10,
    parameter NUM_STATES  = 1024
)(
    input  wire clk,
    input  wire rst,

    // Sinal para iniciar uma operação do Q-Learning
    input  wire start,

    // Estado vindo da L2
    input  wire [STATE_WIDTH-1:0] state,

    // Resultado do acesso: hit ou miss
    input  wire hit,

    // Via escolhida pelo Q-Learning: 0 até 7
    output wire [2:0] victim_way,

    // Sinais de status
    output wire busy,
    output wire done,

    // Debug
    output wire en_regs_dbg,
    output wire wr_table_dbg,
    output wire signed [Q_WIDTH-1:0] new_q_dbg,
    output wire [STATE_WIDTH-1:0] state_d3_dbg,
    output wire [2:0] action_d3_dbg,
    output wire write_en_dbg,
    output wire [2:0] write_way_dbg
);

    // ============================================================
    // Sinais internos entre controle e datapath/top
    // ============================================================

    wire en_regs;
    wire wr_table;

    // ============================================================
    // Controle do Q-Learning
    // ============================================================
    //
    // Essa FSM já existia no projeto antigo.
    // Ela controla quando o datapath calcula e quando a Q-table escreve.
    // ============================================================

    qlearning_control control_inst (
        .clk(clk),
        .rst(rst),
        .start(start),

        .en_regs(en_regs),
        .wr_table(wr_table),

        .busy(busy),
        .done(done)
    );

    // ============================================================
    // Núcleo Q-Learning 8-way
    // ============================================================
    //
    // Esse bloco contém:
    // - q_table_8way
    // - qlearning_datapath_8way
    // ============================================================

    qlearning_top_8way #(
        .Q_WIDTH(Q_WIDTH),
        .STATE_WIDTH(STATE_WIDTH),
        .NUM_STATES(NUM_STATES)
    ) qlearning_top_inst (
        .clk(clk),
        .rst(rst),

        .state(state),
        .hit(hit),

        .en_regs(en_regs),
        .wr_table(wr_table),

        .victim_way(victim_way),

        .new_q_dbg(new_q_dbg),
        .state_d3_dbg(state_d3_dbg),
        .action_d3_dbg(action_d3_dbg),
        .write_en_dbg(write_en_dbg),
        .write_way_dbg(write_way_dbg)
    );

    // ============================================================
    // Debug
    // ============================================================

    assign en_regs_dbg  = en_regs;
    assign wr_table_dbg = wr_table;

endmodule