`timescale 1ns/1ps

module qlearning_top_8way #(
    parameter Q_WIDTH     = 32,
    parameter STATE_WIDTH = 10,
    parameter NUM_STATES  = 1024
)(
    input  wire clk,
    input  wire rst,

    // Estado vindo da L2
    input  wire [STATE_WIDTH-1:0] state,

    // Resultado do acesso: hit ou miss
    input  wire hit,

    // Sinais de controle vindos da FSM
    input  wire en_regs,
    input  wire wr_table,

    // Via escolhida pelo Q-Learning: 0 a 7
    output wire [2:0] victim_way,

    // Debug
    output wire signed [Q_WIDTH-1:0] new_q_dbg,
    output wire [STATE_WIDTH-1:0] state_d3_dbg,
    output wire [2:0] action_d3_dbg,
    output wire write_en_dbg,
    output wire [2:0] write_way_dbg
);

    // ============================================================
    // Fios entre Q-table e datapath
    // ============================================================

    wire signed [Q_WIDTH-1:0] q0;
    wire signed [Q_WIDTH-1:0] q1;
    wire signed [Q_WIDTH-1:0] q2;
    wire signed [Q_WIDTH-1:0] q3;
    wire signed [Q_WIDTH-1:0] q4;
    wire signed [Q_WIDTH-1:0] q5;
    wire signed [Q_WIDTH-1:0] q6;
    wire signed [Q_WIDTH-1:0] q7;

    // ============================================================
    // Fios de escrita na Q-table
    // ============================================================

    wire write_en;
    wire [STATE_WIDTH-1:0] write_state;
    wire [2:0] write_way;
    wire signed [Q_WIDTH-1:0] write_data;

    // ============================================================
    // Q-table 8-way
    // ============================================================
    //
    // A Q-table guarda os valores Q para cada estado e para cada
    // uma das 8 acoes possíveis, ou seja, as 8 vias da L2.
    // ============================================================

    q_table_8way #(
        .Q_WIDTH(Q_WIDTH),
        .STATE_WIDTH(STATE_WIDTH),
        .NUM_STATES(NUM_STATES)
    ) q_table_inst (
        .clk(clk),

        .read_state(state),
        .write_state(write_state),
        .write_data(write_data),

        .write_en(write_en),
        .write_way(write_way),

        .q0(q0),
        .q1(q1),
        .q2(q2),
        .q3(q3),
        .q4(q4),
        .q5(q5),
        .q6(q6),
        .q7(q7)
    );

    // ============================================================
    // Datapath 8-way
    // ============================================================
    //
    // O datapath compara q0..q7, escolhe a melhor acao/via,
    // calcula o novo valor Q e gera os sinais de escrita.
    // ============================================================

    qlearning_datapath_8way #(
        .Q_WIDTH(Q_WIDTH),
        .STATE_WIDTH(STATE_WIDTH)
    ) datapath_inst (
        .clk(clk),
        .rst(rst),

        .en_regs(en_regs),
        .wr_table(wr_table),

        .state(state),
        .hit(hit),

        .q0(q0),
        .q1(q1),
        .q2(q2),
        .q3(q3),
        .q4(q4),
        .q5(q5),
        .q6(q6),
        .q7(q7),

        .victim_way(victim_way),

        .write_en(write_en),
        .write_state(write_state),
        .write_way(write_way),
        .write_data(write_data),

        .new_q_dbg(new_q_dbg),
        .state_d3_dbg(state_d3_dbg),
        .action_d3_dbg(action_d3_dbg)
    );

    // ============================================================
    // Debug
    // ============================================================

    assign write_en_dbg  = write_en;
    assign write_way_dbg = write_way;

endmodule