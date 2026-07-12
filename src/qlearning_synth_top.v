    module qlearning_synth_top #(
        parameter Q_WIDTH = 32,
        parameter STATE_WIDTH = 10,
        parameter NUM_STATES = 1024
    )(
        input  wire clk,
        input  wire rst,
        input  wire start,

        input  wire [STATE_WIDTH-1:0] state,
        input  wire hit,

        output wire busy,
        output wire done,
        output wire victim_way,

        // Saídas reduzidas para debug físico/síntese
        output wire [7:0] q0_dbg_low,
        output wire [7:0] q1_dbg_low,
        output wire [7:0] new_q_dbg_low,

        output wire [STATE_WIDTH-1:0] state_d3_dbg,
        output wire action_d3_dbg,

        output wire wr_way0_dbg,
        output wire wr_way1_dbg,
        output wire en_regs_dbg,
        output wire wr_table_dbg
    );

        wire signed [Q_WIDTH-1:0] q0_dbg;
        wire signed [Q_WIDTH-1:0] q1_dbg;
        wire signed [Q_WIDTH-1:0] new_q_dbg;

        qlearning_system #(
            .Q_WIDTH(Q_WIDTH),
            .STATE_WIDTH(STATE_WIDTH),
            .NUM_STATES(NUM_STATES)
        ) system_inst (
            .clk(clk),
            .rst(rst),
            .start(start),

            .state(state),
            .hit(hit),

            .busy(busy),
            .done(done),
            .victim_way(victim_way),

            .q0_dbg(q0_dbg),
            .q1_dbg(q1_dbg),
            .new_q_dbg(new_q_dbg),

            .state_d3_dbg(state_d3_dbg),
            .action_d3_dbg(action_d3_dbg),

            .wr_way0_dbg(wr_way0_dbg),
            .wr_way1_dbg(wr_way1_dbg),

            .en_regs_dbg(en_regs_dbg),
            .wr_table_dbg(wr_table_dbg)
        );

        assign q0_dbg_low    = q0_dbg[7:0];
        assign q1_dbg_low    = q1_dbg[7:0];
        assign new_q_dbg_low = new_q_dbg[7:0];

    endmodule