`timescale 1ns/1ps

module cache_l2_ql_8way #(
    parameter ADDR_WIDTH  = 16,
    parameter INDEX_BITS  = 6,  // 64 conjuntos
    parameter OFFSET_BITS = 6,  // bloco de 64 bytes
    parameter WAYS        = 8   // 8 vias
)(
    input  wire clk,
    input  wire rst,

    // Requisicao vinda da hierarquia depois de miss na L1
    input  wire req,
    input  wire [ADDR_WIDTH-1:0] addr,

    // Resultado do acesso na L2
    output reg done,
    output reg hit,
    output reg miss,

    // Representa acesso a memoria principal ficticia
    output reg mem_access,

    // Sinais de debug do nucleo Q-Learning
    output reg        q_start_dbg,
    output wire       q_done_dbg,
    output wire [2:0] q_victim_way_dbg
);

    // ============================================================
    // Parametros derivados da L2
    // ============================================================
    //
    // Para a configuracao final:
    //
    // ADDR_WIDTH  = 16
    // INDEX_BITS  = 6  -> 2^6 = 64 conjuntos
    // OFFSET_BITS = 6  -> 2^6 = 64 bytes por bloco
    // WAYS        = 8
    //
    // Capacidade logica:
    // 64 conjuntos × 8 vias × 64 bytes = 32768 bytes = 32 KB
    // ============================================================

    localparam SETS          = (1 << INDEX_BITS);
    localparam TAG_BITS      = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;

    // O Q-Learning continua usando 10 bits de estado.
    // Agora, como o set da L2 tem 6 bits, sobram 4 bits para tag reduzida:
    //
    // q_state = {set_idx[5:0], tag_reduzida[3:0]}
    //
    // Total: 6 + 4 = 10 bits
    localparam Q_STATE_WIDTH = 10;
    localparam Q_TAG_BITS    = Q_STATE_WIDTH - INDEX_BITS;

    // ============================================================
    // Estruturas da L2 8-way
    // ============================================================
    //
    // valid[set][way]
    // tag[set][way]
    //
    // Exemplo:
    // tag[3][5] = tag da via 5 no conjunto 3
    // ============================================================

    reg valid [0:SETS-1][0:WAYS-1];
    reg [TAG_BITS-1:0] tag [0:SETS-1][0:WAYS-1];

    // Endereco registrado para manter estavel durante a FSM
    reg [ADDR_WIDTH-1:0] addr_reg;

    wire [INDEX_BITS-1:0] set_idx;
    wire [TAG_BITS-1:0]   tag_in;

    assign set_idx = addr_reg[OFFSET_BITS + INDEX_BITS - 1 : OFFSET_BITS];
    assign tag_in  = addr_reg[ADDR_WIDTH-1 : OFFSET_BITS + INDEX_BITS];

    // ============================================================
    // Busca combinacional por hit ou via livre
    // ============================================================

    reg hit_found;

    reg invalid_found;
    reg [2:0] invalid_way;

    integer w;

    always @(*) begin
        hit_found     = 1'b0;
        invalid_found = 1'b0;
        invalid_way   = 3'd0;

        for (w = 0; w < WAYS; w = w + 1) begin

            // Procura hit em qualquer uma das 8 vias
            if (!hit_found && valid[set_idx][w] && (tag[set_idx][w] == tag_in)) begin
                hit_found = 1'b1;
            end

            // Procura a primeira via livre
            if (!invalid_found && !valid[set_idx][w]) begin
                invalid_found = 1'b1;
                invalid_way   = w[2:0];
            end
        end
    end

    // ============================================================
    // Sinais para o nucleo Q-Learning 8-way
    // ============================================================

    reg q_start;
    reg [Q_STATE_WIDTH-1:0] q_state;

    wire q_busy;
    wire q_done;
    wire [2:0] q_victim_way;

    reg [2:0] q_victim_reg;

    assign q_done_dbg       = q_done;
    assign q_victim_way_dbg = q_victim_way;

    // ============================================================
    // Nucleo Q-Learning 8-way
    // ============================================================
    //
    // O Q-Learning e chamado quando:
    //
    // 1. ocorre miss na L2;
    // 2. nao existe via livre;
    // 3. o conjunto ja esta cheio.
    //
    // A entrada hit fica em 0 nesta versao, pois o nucleo e acionado
    // apenas no caso de miss com substituicao.
    // ============================================================

    qlearning_system_8way #(
        .STATE_WIDTH(Q_STATE_WIDTH)
    ) qcore (
        .clk(clk),
        .rst(rst),

        .start(q_start),
        .state(q_state),
        .hit(1'b0),

        .victim_way(q_victim_way),

        .busy(q_busy),
        .done(q_done),

        .en_regs_dbg(),
        .wr_table_dbg(),
        .new_q_dbg(),
        .state_d3_dbg(),
        .action_d3_dbg(),
        .write_en_dbg(),
        .write_way_dbg()
    );

    // ============================================================
    // FSM da L2
    // ============================================================

    localparam S_IDLE   = 3'd0;
    localparam S_LOOKUP = 3'd1;
    localparam S_QSTART = 3'd2;
    localparam S_QWAIT  = 3'd3;
    localparam S_FILL   = 3'd4;

    reg [2:0] fsm;

    integer i;
    integer j;

    always @(posedge clk) begin
        if (rst) begin
            fsm <= S_IDLE;

            done       <= 1'b0;
            hit        <= 1'b0;
            miss       <= 1'b0;
            mem_access <= 1'b0;

            q_start      <= 1'b0;
            q_start_dbg  <= 1'b0;
            q_state      <= {Q_STATE_WIDTH{1'b0}};
            q_victim_reg <= 3'd0;

            addr_reg <= {ADDR_WIDTH{1'b0}};

            for (i = 0; i < SETS; i = i + 1) begin
                for (j = 0; j < WAYS; j = j + 1) begin
                    valid[i][j] <= 1'b0;
                    tag[i][j]   <= {TAG_BITS{1'b0}};
                end
            end

        end else begin
            // Saidas em pulso de 1 ciclo
            done       <= 1'b0;
            hit        <= 1'b0;
            miss       <= 1'b0;
            mem_access <= 1'b0;

            q_start     <= 1'b0;
            q_start_dbg <= 1'b0;

            case (fsm)

                // ====================================================
                // Espera requisicao da hierarquia
                // ====================================================
                S_IDLE: begin
                    if (req) begin
                        addr_reg <= addr;
                        fsm <= S_LOOKUP;
                    end
                end

                // ====================================================
                // Verifica se o endereco esta na L2
                // ====================================================
                S_LOOKUP: begin

                    // Caso 1: hit em alguma das 8 vias
                    if (hit_found) begin
                        done <= 1'b1;
                        hit  <= 1'b1;

                        fsm <= S_IDLE;
                    end

                    // Caso 2: miss, mas existe via livre
                    else if (invalid_found) begin
                        valid[set_idx][invalid_way] <= 1'b1;
                        tag[set_idx][invalid_way]   <= tag_in;

                        done       <= 1'b1;
                        miss       <= 1'b1;
                        mem_access <= 1'b1;

                        fsm <= S_IDLE;
                    end

                    // Caso 3: miss e todas as 8 vias estao ocupadas
                    // Aqui chamamos o Q-Learning para escolher a vitima.
                    else begin
                        // Estado de 10 bits:
                        // INDEX_BITS bits do conjunto + Q_TAG_BITS bits da tag reduzida
                        //
                        // Com INDEX_BITS = 6:
                        // q_state = {set_idx[5:0], tag_in[3:0]}
                        q_state <= {set_idx, tag_in[Q_TAG_BITS-1:0]};

                        fsm <= S_QSTART;
                    end
                end

                // ====================================================
                // Pulso de start para o Q-Learning
                // ====================================================
                S_QSTART: begin
                    q_start     <= 1'b1;
                    q_start_dbg <= 1'b1;

                    fsm <= S_QWAIT;
                end

                // ====================================================
                // Espera o Q-Learning terminar
                // ====================================================
                S_QWAIT: begin
                    if (q_done) begin
                        q_victim_reg <= q_victim_way;

                        fsm <= S_FILL;
                    end
                end

                // ====================================================
                // Substitui a via escolhida pelo Q-Learning
                // ====================================================
                S_FILL: begin
                    valid[set_idx][q_victim_reg] <= 1'b1;
                    tag[set_idx][q_victim_reg]   <= tag_in;

                    done       <= 1'b1;
                    miss       <= 1'b1;
                    mem_access <= 1'b1;

                    fsm <= S_IDLE;
                end

                default: begin
                    fsm <= S_IDLE;
                end

            endcase
        end
    end

endmodule