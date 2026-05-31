// 1. CORREÇÃO DE ESCOPO: Typedefs de portas precisam vir ANTES do módulo no Icarus Verilog
typedef struct packed {
    logic [19:0][3:0] digits;
} digitosPac_t;

typedef enum logic [3:0] {
    ESPERA_TECLA,
    DEBOUNCE,
    DECODIFICA_E_VALIDA,
    ARMAZENAR_DIGITO,
    LEVANTA_FLAG_TIMEOUT,
    RESET_TIMEOUT,
    VERIFICA_PRESSIONAMENTO_DIGITO,
    TECLA_ENTER,
    TECLA_APAGAR,
    ATIVA_FLAG_POR_UM_PULSO_CLOCK,
    LIMPA_BARRAMENTO,
    ESPERA_SOLTAR_TECLA
} estados_t;

module decodificador_de_teclado (
    input   logic           clk,
    input   logic           rst,
    input   logic           enable,
    input   logic [3:0]     col_matriz,
    output  logic [3:0]     lin_matriz,
    output  digitosPac_t    digitos_value,
    output  logic           digitos_valid
);

    estados_t estado;
    logic [3:0] indice_linha;

    logic [31:0] time_espera_tecla;
    logic [31:0] time_start_timeout;
    logic [31:0] time_start_enter;
    logic [31:0] time_start_guarda_digito;

    logic [15:0] debounce_cnt;
    logic [3:0]  digito_bcd;
    logic        lendo_digitos;

    // CORREÇÃO DE STRUCT: Tratamos como vetor de bits flat para compatibilidade com Icarus
    logic [79:0] senhaPac_flat;
    logic [4:0]  cont_digito;
    logic        primeira_repeticao;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            estado                    <= ESPERA_TECLA;
            time_espera_tecla         <= 32'b0;
            time_start_timeout        <= 32'b0;
            time_start_enter          <= 32'b0;
            time_start_guarda_digito  <= 32'b0;
            debounce_cnt              <= 0;
            cont_digito               <= 0;
            indice_linha              <= 4'b0111;
            digito_bcd                <= 4'hF;
            primeira_repeticao        <= 1'b1;
            senhaPac_flat             <= {20{4'hF}}; // Inicializa o vetor flat todo com F
            lendo_digitos             <= 1'b0;
        end else if (enable) begin
            case (estado)
                ESPERA_TECLA: begin
                    if (col_matriz == 4'b1111) begin
                        indice_linha      <= {indice_linha[2:0], indice_linha[3]};
                        time_espera_tecla <= time_espera_tecla + 1;

                        if (time_espera_tecla >= 5000) begin
                            time_espera_tecla <= 32'b0;
                            estado            <= LEVANTA_FLAG_TIMEOUT;
                        end
                    end else begin
                        time_espera_tecla <= 32'b0;
                        estado            <= DEBOUNCE;
                    end
                end

                DEBOUNCE: begin
                    if (col_matriz == 4'b1111) begin
                        debounce_cnt <= 0;
                        estado       <= ESPERA_TECLA;
                    end else if (debounce_cnt < 19) begin
                        debounce_cnt <= debounce_cnt + 1;
                    end else begin
                        debounce_cnt <= 0;
                        estado       <= DECODIFICA_E_VALIDA;
                    end
                end

                DECODIFICA_E_VALIDA: begin
                    primeira_repeticao <= 1'b1;

                    case ({indice_linha, col_matriz})
                        {4'b0111, 4'b0111}: begin digito_bcd <= 4'h1; estado <= ARMAZENAR_DIGITO; end
                        {4'b0111, 4'b1011}: begin digito_bcd <= 4'h2; estado <= ARMAZENAR_DIGITO; end
                        {4'b0111, 4'b1101}: begin digito_bcd <= 4'h3; estado <= ARMAZENAR_DIGITO; end
                        {4'b1011, 4'b0111}: begin digito_bcd <= 4'h4; estado <= ARMAZENAR_DIGITO; end
                        {4'b1011, 4'b1011}: begin digito_bcd <= 4'h5; estado <= ARMAZENAR_DIGITO; end
                        {4'b1011, 4'b1101}: begin digito_bcd <= 4'h6; estado <= ARMAZENAR_DIGITO; end
                        {4'b1101, 4'b0111}: begin digito_bcd <= 4'h7; estado <= ARMAZENAR_DIGITO; end
                        {4'b1101, 4'b1011}: begin digito_bcd <= 4'h8; estado <= ARMAZENAR_DIGITO; end
                        {4'b1101, 4'b1101}: begin digito_bcd <= 4'h9; estado <= ARMAZENAR_DIGITO; end

                        {4'b1110, 4'b0111}: begin digito_bcd <= 4'hA; estado <= TECLA_ENTER; end
                        {4'b1110, 4'b1011}: begin digito_bcd <= 4'h0; estado <= ARMAZENAR_DIGITO; end
                        {4'b1110, 4'b1101}: begin digito_bcd <= 4'hB; estado <= TECLA_APAGAR; end

                        default: begin digito_bcd <= 4'hF; estado <= ESPERA_TECLA; end
                    endcase
                end

                ARMAZENAR_DIGITO: begin
                    // CORREÇÃO: Operação de shift no vetor flat nativo para o Icarus aceitar estavelmente
                    senhaPac_flat <= {senhaPac_flat[75:0], digito_bcd};
                    estado        <= VERIFICA_PRESSIONAMENTO_DIGITO;
                end

                VERIFICA_PRESSIONAMENTO_DIGITO: begin
                    if (col_matriz != 4'b1111) begin
                        time_start_guarda_digito <= time_start_guarda_digito + 1;

                        if (primeira_repeticao) begin
                            if (time_start_guarda_digito >= 2000) begin
                                time_start_guarda_digito <= 32'b0;
                                primeira_repeticao       <= 1'b0;
                                estado                   <= ARMAZENAR_DIGITO;
                            end
                        end else begin
                            if (time_start_guarda_digito >= 1000) begin
                                time_start_guarda_digito <= 32'b0;
                                estado                   <= ARMAZENAR_DIGITO;
                            end
                        end
                    end else begin
                        time_start_guarda_digito <= 32'b0;
                        estado                   <= ESPERA_TECLA;
                    end
                end

                TECLA_APAGAR: begin
                    senhaPac_flat <= {20{4'hB}};
                    estado        <= ATIVA_FLAG_POR_UM_PULSO_CLOCK;
                end

                LEVANTA_FLAG_TIMEOUT: begin
                    senhaPac_flat <= {20{4'hE}};
                    estado        <= RESET_TIMEOUT;
                end

                TECLA_ENTER: begin
                    estado <= ATIVA_FLAG_POR_UM_PULSO_CLOCK;
                end

                ATIVA_FLAG_POR_UM_PULSO_CLOCK: begin
                    lendo_digitos <= 1'b1; // Sincronizado internamente para evitar multi-driver
                    estado        <= LIMPA_BARRAMENTO;
                end

                RESET_TIMEOUT: begin
                    estado <= LIMPA_BARRAMENTO;
                end

                LIMPA_BARRAMENTO: begin
                    senhaPac_flat <= {20{4'hF}};
                    estado        <= ESPERA_SOLTAR_TECLA;
                end

                ESPERA_SOLTAR_TECLA: begin
                    if (col_matriz == 4'b1111) begin
                        estado <= ESPERA_TECLA;
                    end else begin
                        estado <= ESPERA_SOLTAR_TECLA;
                    end
                end

                default: estado <= ESPERA_TECLA;
            endcase
        end
    end

    // Bloco Combinacional Limpo e Livre de Latches perigosos
    always_comb begin
        digitos_valid = 1'b0;
        lin_matriz    = indice_linha;
        
        // Mapeia o barramento flat interno para a assinatura struct da saída externa
        digitos_value = senhaPac_flat; 

        if (estado == ATIVA_FLAG_POR_UM_PULSO_CLOCK || estado == RESET_TIMEOUT) begin
            digitos_valid = 1'b1;
        end
    end

endmodule