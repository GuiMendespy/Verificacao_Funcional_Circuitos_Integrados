`timescale 1ns/1ps
`define DEBUG 0
`define MAX_COBERTURA 10
`define DEBOUNCE_PRESSIONAMENTO 100
`define MAX_ESPERA 20

module tb_teclado;

    logic clk, rst, enable;
    logic [3:0] col_matriz;
    logic [3:0] lin_matriz;
    digitosPac_t digitos_value;
    logic digitos_valid;

    decodificador_de_teclado dut (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .col_matriz(col_matriz),
        .lin_matriz(lin_matriz),
        .digitos_value(digitos_value),
        .digitos_valid(digitos_valid)
    );

    always #0.5 clk = ~clk;

    initial begin
        clk = 0;
        enable = 1;
    end

    bit [3:0] num;
    integer hit_count[10];

    // ================================================================
    // Utilitarios
    // ================================================================

    function logic [7:0] get_coords(input logic [3:0] d);
        case (d)
            4'h0:    return 8'b1110_1011;
            4'h1:    return 8'b0111_0111;
            4'h2:    return 8'b0111_1011;
            4'h3:    return 8'b0111_1101;
            4'h4:    return 8'b1011_0111;
            4'h5:    return 8'b1011_1011;
            4'h6:    return 8'b1011_1101;
            4'h7:    return 8'b1101_0111;
            4'h8:    return 8'b1101_1011;
            4'h9:    return 8'b1101_1101;
            default: return 8'b1111_1111;
        endcase
    endfunction

    task pressionar_digito(input logic [3:0] d);
        logic [7:0] coords;
        coords = get_coords(d);

        if (`DEBUG) $display("[DEBUG TB] Iniciando pressionamento de %1d...", d);

        while (lin_matriz !== coords[7:4]) begin
            if (`DEBUG) $display("[DEBUG TB] lin_matriz = 0b%4b", lin_matriz);
            @(posedge clk);
        end
        col_matriz = coords[3:0];
        repeat(`DEBOUNCE_PRESSIONAMENTO) @(posedge clk);
        col_matriz = 4'b1111;

        if (`DEBUG) $display("[DEBUG TB] Pressionamento finalizado.");
    endtask

    task pressionar_asterisco;
        if (`DEBUG) $display("[DEBUG TB] Iniciando confirmamento...");

        while (lin_matriz !== 4'b1110) @(posedge clk);
        col_matriz = 4'b0111;
        repeat(`DEBOUNCE_PRESSIONAMENTO) @(posedge clk);
        col_matriz = 4'b1111;
        repeat(`MAX_ESPERA) @(posedge clk);

        if (`DEBUG) $display("[DEBUG TB] Confirmamento finalizado.");
    endtask

    task pressionar_hashtag;
        if (`DEBUG) $display("[DEBUG TB] Iniciando pressionamento de #...");
        while (lin_matriz !== 4'b1110) @(posedge clk);
        col_matriz = 4'b1101;
        repeat(`DEBOUNCE_PRESSIONAMENTO) @(posedge clk);
        col_matriz = 4'b1111;
        repeat(`MAX_ESPERA) @(posedge clk);
        if (`DEBUG) $display("[DEBUG TB] Pressionamento de # finalizado.");
    endtask

    task fazer_reset;
        if (`DEBUG) $display("[DEBUG TB] Iniciando reset...");
        col_matriz = 4'b1111;
        rst    = 1;
        repeat(5) @(posedge clk);
        rst    = 0;
        repeat(5) @(posedge clk);
        if (`DEBUG) $display("[DEBUG TB] Reset finalizado.");
    endtask

    task linha(input bit m);
        if (m)
            $display("===============================================");
        else
            $display("-----------------------------------------------");
    endtask

    task gerar_num_aleatorio(output bit [3:0] numero_out);
        numero_out = $urandom_range(0, 9);
        if (`DEBUG) $display("[DEBUG TB] Número aleatório gerado: %d", numero_out);
    endtask

    function bit cobertura_completa;
        for (int i = 0; i <= 9; i++)
            if (hit_count[i] < `MAX_COBERTURA) return 0;
        return 1;
    endfunction

    task limpar_cobertura;
        foreach (hit_count[i]) hit_count[i] = 0;
        if (`DEBUG) $display("[DEBUG TB] Cobertura limpa.");
    endtask

    task exibir_cobertura;
        int c;
        integer cobertos;
        c = 0;
        cobertos = 0;
        $display("             RELATORIO DE COBERTURA");
        linha(0);
        for (int i = 0; i <= 9; i++) begin
            $display(
                " Digito %0d: %0d/%1d \t\t    %s",
                i,
                hit_count[i],
                `MAX_COBERTURA,
                hit_count[i] >= `MAX_COBERTURA ? "[COBERTO]" : "[PENDENTE]"
            );
            if (hit_count[i] >= `MAX_COBERTURA) cobertos++;
        end
        linha(0);
        for (int i = 0; i <= 9; i++)
            c += hit_count[i];
        $display("  Total: %0d/10 digitos cobertos (%.0f%%)", cobertos, c * 100 / (10 * `MAX_COBERTURA));
        linha(1);
    endtask

    // ================================================================
    // CENARIO 1 — Decodificação do teclado
    // ================================================================
    task teste_decodificar_teclado;
        bit [3:0] esperado;

        $display("           CENÁRIO 1: DECODIFICAÇÃO");
        linha(1);

        fazer_reset();
        limpar_cobertura();
        exibir_cobertura();

        while (!cobertura_completa()) begin
            gerar_num_aleatorio(num);

            pressionar_digito(num);
            repeat(`MAX_ESPERA) @(posedge clk);

            if (digitos_value.digits[0] != num) begin
                $display("[FALHA] Esperado: %X, Obtido: %X", num, digitos_value.digits[0]);
                $finish;
            end
            else if (hit_count[num] < `MAX_COBERTURA)
                hit_count[num]++;

            $write("\x1b[15A");
            exibir_cobertura();
        end
    endtask

    // ================================================================
    // CENARIO 2 — Shift do barramento
    // ================================================================
    task teste_shift_barramento;
        digitosPac_t sequencia_esperada;
        logic [3:0] digito_atual;
        integer erros;

        $display("               CENARIO 2: Shift");
        linha(1);

        fazer_reset();
        sequencia_esperada = ~0;

        $display(" Digitando sequencia de 0-9 duas vezes...");
        linha(0);
        for (int i = 0; i < 20; i++) begin
            digito_atual = i % 10;
            sequencia_esperada = (sequencia_esperada << 4) | digito_atual;
            pressionar_digito(digito_atual);
            repeat(`MAX_ESPERA) @(posedge clk);

            $display(" Digitando %1d...           %20h", digito_atual, digitos_value);
            if (digitos_value != sequencia_esperada) begin
                $display("%20h = %20h : %1b", digitos_value, sequencia_esperada, digitos_value == sequencia_esperada);
                $finish;
            end
            if (`DEBUG) $display("%20h = %20h : %1b", digitos_value, sequencia_esperada, digitos_value == sequencia_esperada);
        end

        linha(0);
        $display(" Digitando 50 números aleatórios...");
        linha(0);

        for (int i = 0; i < 50; i++) begin
            gerar_num_aleatorio(digito_atual);

            sequencia_esperada = (sequencia_esperada << 4) | digito_atual;

            pressionar_digito(digito_atual);
            repeat(`MAX_ESPERA) @(posedge clk);

            $display(" Digitando %1d...           %20h", digito_atual, digitos_value);
            if (digitos_value != sequencia_esperada) begin
                $display("%20h = %20h : %1b", digitos_value, sequencia_esperada, digitos_value == sequencia_esperada);
                $finish;
            end
            if (`DEBUG) $display("%20h = %20h : %1b", digitos_value, sequencia_esperada, digitos_value == sequencia_esperada);
        end

        linha(1);
    endtask

    // ================================================================
    // CENARIO 3 — Debounce
    // ================================================================
    task teste_debounce_tecla(input logic [3:0] tecla);
        logic [7:0] coords;
        logic [3:0] l, c;
        logic [7:0] i;

        integer limite_max_press;
        integer ciclos_pressionado;
        integer ciclos_solto;
        longint t_inicio;
        linha(1);

        fazer_reset();

        coords = get_coords(tecla);
        l      = coords[7:4];
        c      = coords[3:0];

        $display(" Tecla alvo: %0d", tecla);
        linha(0);

        limite_max_press   = 5;
        t_inicio           = $time;


        fork : ruidos
            begin
                for (i = 0; i < 100; i++) @(posedge clk);
                disable ruidos;
            end
            begin
                while (1) begin
                    ciclos_pressionado = $urandom_range(1, limite_max_press);
                    ciclos_solto       = $urandom_range(2, 15);

                    while (lin_matriz != l) @(posedge clk);
                    col_matriz = c;
                    $display(" [%03dns] Ruído com duração %1dns", $time - t_inicio, ciclos_pressionado);

                    repeat (ciclos_pressionado) @(posedge clk);

                    col_matriz = 4'b1111;

                    repeat (ciclos_solto) @(posedge clk);

                    limite_max_press = (limite_max_press * 5)/3;
                end
            end
        join

        while (lin_matriz != l) @(posedge clk);
        col_matriz = c;
        $display(" [%03dns] O sinal estabilizou", $time - t_inicio);

        repeat(`DEBOUNCE_PRESSIONAMENTO) @(posedge clk);
        $display(" [%03dns] O sinal passou o debounce", $time - t_inicio);

        repeat(`MAX_ESPERA) @(posedge clk);

            $display(" [%03dns] Barramento: %20h", $time - t_inicio, digitos_value);
        linha(0);
        // Validação final do barramento
        if (digitos_value == (~0 << 4) | tecla) begin
            $display(" [SUCESSO] Tecla %0d foi gravada no barramento!", tecla);
        end
        else begin
            $display(" [FALHA] O sinal estabilizou mas o barramento contem: 0x%X (esperado: 0x%X)", digitos_value.digits[0], tecla);
        end
    endtask

    task teste_debounce;
        $display("              CENARIO 3: Debounce");

        for (int i = 0; i < 10; i++) begin
            teste_debounce_tecla(i);
        end

        linha(1);
    endtask

    // ================================================================
    // CENARIO 4 — Repeticao automatica da tecla
    // ================================================================
    task teste_repeticao_tecla;
        logic [3:0] tecla;
        logic [7:0] coords;
        logic [3:0] l, c;
        logic [79:0] shadow_matrix;

        $display("   CENARIO 4: Repetição Automática de Teclas");
        linha(1);

        fazer_reset();

        gerar_num_aleatorio(tecla);
        coords = get_coords(tecla);
        l      = coords[7:4];
        c      = coords[3:0];

        $display(" Tecla sorteada para teste de pressao longa: %0d", tecla);
        linha(0);

        while (lin_matriz !== l) @(posedge clk);
        col_matriz = c;
        repeat(`DEBOUNCE_PRESSIONAMENTO) @(posedge clk);

        shadow_matrix = digitos_value;
        if (shadow_matrix[3:0] === tecla) begin
            $display(" [OK] Tecla %0d registrada pela primeira vez com sucesso!", tecla);
        end else begin
            $display(" [AVISO] Tecla ainda nao apareceu no barramento. Obtido: 0x%X", shadow_matrix[3:0]);
        end

        $display(" Mantendo pressionado... aguardando 2000 clks para a 1a repeticao...");
        repeat(2000) @(posedge clk);

        shadow_matrix = digitos_value;
        $display(" Checando o barramento apos os primeiros 2 segundos...");
        if (shadow_matrix[3:0] === tecla && shadow_matrix[7:4] === tecla) begin
            $display(" [SUCESSO] 1a Repeticao Detectada! O digito duplicou: [0]=0x%X, [1]=0x%X",
                     shadow_matrix[3:0], shadow_matrix[7:4]);
        end else begin
            $display(" [AVISO] A 1a repeticao nao aconteceu apos 2s. Barramento: [0]=0x%X, [1]=0x%X",
                     shadow_matrix[3:0], shadow_matrix[7:4]);
        end

        $display(" Mantendo pressionado... aguardando +1000 clks para a 2a repeticao (ritmo de 1s)...");
        repeat(1000) @(posedge clk);

        shadow_matrix = digitos_value;
        $display(" Checando o barramento apos mais 1 segundo...");
        if (shadow_matrix[3:0] === tecla && shadow_matrix[7:4] === tecla && shadow_matrix[11:8] === tecla) begin
            $display(" [SUCESSO] 2a Repeticao Detectada! O digito triplicou: [0]=0x%X, [1]=0x%X, [2]=0x%X",
                     shadow_matrix[3:0], shadow_matrix[7:4], shadow_matrix[11:8]);
        end else begin
            $display(" [AVISO] A 2a repeticao falhou ou ritmo de 1s nao foi obedecido. Barramento: [0]=0x%X, [1]=0x%X, [2]=0x%X",
                     shadow_matrix[3:0], shadow_matrix[7:4], shadow_matrix[11:8]);
        end

        col_matriz = 4'b1111;
        repeat(20) @(posedge clk);

        linha(0);
        $display("        RELATORIO DE REPETICAO AUTOMATICA");
        linha(0);
        if (digitos_value.digits[0] === tecla && digitos_value.digits[1] === tecla && digitos_value.digits[2] === tecla) begin
            $display(" [SUCESSO] Maquina de estados obedeceu perfeitamente os tempos (Debounce -> 2s -> 1s)!");
        end else if (digitos_value.digits[0] === tecla && digitos_value.digits[1] === tecla) begin
            $display(" [PARCIAL] Apenas uma repeticao ocorreu. Verifique se o loop continuo de 1s esta ativo.");
        end else if (digitos_value.digits[0] === tecla) begin
            $display(" [LIMITADO] Tecla registrada apenas 1 vez. O circuito nao possui auto-repeat.");
        end else begin
            $display(" [FALHA] A tecla sequer foi registrada no teste.");
        end

        linha(1);
        repeat(20) @(posedge clk);
    endtask

    // ================================================================
    // CENARIO 5 — Confirmacao com tecla *
    // ================================================================
    task teste_confirmacao_asterisco;
        localparam integer N = 5;
        logic [3:0]  digitados [N];
        logic [3:0]  esperado_k;
        logic [3:0]  obtido_k;
        logic [79:0] barramento_plano;
        integer ciclos;
        integer erros_dados;
        integer ok_timing, ok_dados;
        integer k;
        logic [3:0]  digito_atual;
        logic [7:0]  coords_atuais;

        $display("       CENARIO 5: Confirmacao com * (ENTER)");
        linha(1);
        fazer_reset();

        $display(" Digitando %0d teclas aleatorias...", N);
        linha(0);
        for (int i = 0; i < N; i++) begin
            digito_atual = $urandom_range(0, 9);
            digitados[i] = digito_atual;
            coords_atuais = get_coords(digito_atual);

            while (lin_matriz !== coords_atuais[7:4]) @(posedge clk);

            col_matriz = coords_atuais[3:0];

            repeat(110) @(posedge clk);

            col_matriz = 4'b1111;
            repeat(15) @(posedge clk);

            if (`DEBUG) $display("  [%0d/%0d] Digitado: %0d | Registrado em digits[0]: %X", i+1, N, digito_atual, digitos_value.digits[0]);
        end

        repeat(5) @(posedge clk);

        $display(" Barramento antes de acionar o ENTER:");
        barramento_plano = digitos_value;
        for (k = 0; k < N; k++) begin
            $display("  barramento_plano[%0d] = 0x%X", k, barramento_plano[k*4 +: 4]);
        end

        linha(0);
        $display(" Pressionando * (ENTER)...");
        while (lin_matriz !== 4'b1110) @(posedge clk);
        col_matriz = 4'b0111;

        ciclos    = 0;
        ok_timing = 0;

        while (!digitos_valid && ciclos < 200) begin
            @(posedge clk);
            ciclos++;
        end

        col_matriz = 4'b1111; 
        repeat(5) @(posedge clk);

        if (digitos_valid || ciclos < 200) begin
            ok_timing = (ciclos <= 120);
            if (ok_timing)
                $display(" [SUCESSO] digitos_valid subiu em %0d ciclos!", ciclos);
            else
                $display(" [FALHA] digitos_valid demorou %0d ciclos para responder!", ciclos);
        end else begin
            $display(" [FALHA] Timeout: O sinal digitos_valid nao subiu apos 200 ciclos.");
        end

        linha(0);
        $display(" Verificando integridade e ordem dos dados...");
        erros_dados = 0;

        for (k = 0; k < N; k++) begin
            esperado_k = digitados[(N - 1) - k];
            obtido_k   = barramento_plano[k*4 +: 4];

            if (obtido_k !== esperado_k) begin
                $display(" [FALHA] Posicao digits[%0d]: esperado=0x%X | obtido=0x%X", k, esperado_k, obtido_k);
                erros_dados++;
            end else begin
                $display(" [OK] digits[%0d]: esperado=0x%X | obtido=0x%X", k, esperado_k, obtido_k);
            end
        end

        ok_dados = (erros_dados == 0);

        linha(0);
        if (ok_dados && ok_timing)
            $display(" [SUCESSO] Sincronismo perfeito.");
        else
            $display(" [FALHA] (Dados=%0s, Timing=%0s).",
                     ok_dados ? "OK" : "ERRO", ok_timing ? "OK" : "ERRO");
        linha(1);

        repeat(30) @(posedge clk);
    endtask

    // ================================================================
    // CENARIO 6 — Preenchimento com F
    // ================================================================
    task teste_preenchimento_F;
        integer n_digitos;
        bit [3:0] digito_digitado;
        integer erros;

        $display("        CENARIO 6: Preenchimento com F");
        linha(1);

        fazer_reset();
        $display(" Verificando estado inicial apos reset...");
        erros = 0;
        for (int i = 0; i < 20; i++) begin
            if (digitos_value[i*4 +: 4] !== 4'hF) begin
                $display(" [FALHA] digits[%0d] = 0x%X (esperado 0xF)", i, digitos_value[i*4 +: 4]);
                erros++;
            end
        end
        if (erros == 0)
            $display(" [SUCESSO] Inicializado com 20 posicoes em 0xF");
        else
            $display(" [FALHA] %0d posicoes nao estao em 0xF apos reset.", erros);

        for (int t = 0; t < 5; t++) begin
            linha(1);
            fazer_reset();
            n_digitos = $urandom_range(5, 19);
            $display(" Teste %0d/5: Digitando %0d digitos...", t+1, n_digitos);
            linha(0);

            for (int k = 0; k < n_digitos; k++) begin
                gerar_num_aleatorio(digito_digitado);
                pressionar_digito(digito_digitado);

                $display(" Apos %02d digito(s):        %20h", k+1, digitos_value);

                erros = 0;
                for (int j = k+1; j < 20; j++) begin
                    if (digitos_value[j*4 +: 4] !== 4'hF) begin
                        $display(" [FALHA] digits[%0d] = 0x%X (esperado 0xF)", j, digitos_value[j*4 +: 4]);
                        erros++;
                    end
                end
                if (erros == 0)
                    $display(" [OK] Posicoes %0d a 19 estao com 0xF", k+1);
                else
                    $display(" [FALHA] %0d posicao(oes) invalida(s)", erros);
            end
        end

        linha(1);
    endtask

    // ================================================================
    // CENARIO 7 — Limpeza do barramento
    // ================================================================
    task teste_limpeza_barramento;
        bit [3:0] digito_aleatorio;
        integer n_digitos;
        integer ciclos;
        integer erros;

        $display("       CENARIO 7: Limpeza do barramento");
        linha(1);

        for (int t = 0; t < 5; t++) begin
            fazer_reset();
            n_digitos = $urandom_range(1, 30);
            $display(" Rodada %0d/5: Digitando %0d digito(s)...", t+1, n_digitos);
            linha(0);

            for (int k = 0; k < n_digitos; k++) begin
                gerar_num_aleatorio(digito_aleatorio);
                pressionar_digito(digito_aleatorio);
            end

            $display(" Value antes de confirmar: %20h", digitos_value);
            $display(" Pressionando * e aguardando digitos_valid...");

            while (lin_matriz !== 4'b1110) @(posedge clk);
            col_matriz = 4'b0111;

            ciclos = 0;
            while (!digitos_valid && ciclos < 300) begin
                @(posedge clk);
                ciclos++;
            end

            if (ciclos >= 300) begin
                $display(" [FALHA] valid nao subiu apos 300 ciclos!");
                col_matriz = 4'b1111;
                repeat(20) @(posedge clk);
            end else begin
                $display(" [OK] valid subiu em %0d ciclos!", ciclos);
                col_matriz = 4'b1111;
                @(negedge digitos_valid);
                $display(" [OK] Borda de descida de valid detectada!");
                repeat(5) @(posedge clk);

                erros = 0;
                for (int i = 0; i < 20; i++) begin
                    if (digitos_value[i*4 +: 4] !== 4'hF) begin
                        $display(" [FALHA] digits[%0d] = 0x%X (esperado 0xF)", i, digitos_value[i*4 +: 4]);
                        erros++;
                    end
                end
                if (erros == 0)
                    $display(" [SUCESSO] Barramento limpo com 0xF!");
                else
                    $display(" [FALHA] %0d posicao(oes) nao foram resetadas.", erros);
            end

            linha(1);
        end

        $write("\x1b[1A");

        linha(1);
    endtask

    // ================================================================
    // CENARIO 8 — Tecla de desistência #
    // ================================================================
    task teste_hashtag;
        bit [3:0] digito_aleatorio;
        integer n_digitos;
        integer ciclos;
        integer erros_b;
        integer erros_f;

        $display("      CENARIO 8: Tecla de desistencia #");
        linha(1);

        fazer_reset();
        n_digitos = 0;
        $display(" Caso 1: Sem digitos (barramento = Fs)");
        linha(0);
        $display(" Barramento antes do #: %20h", digitos_value);

        while (lin_matriz !== 4'b1110) @(posedge clk);
        col_matriz = 4'b1101;
        ciclos = 0;
        while (!digitos_valid && ciclos < 300) begin
            @(posedge clk);
            ciclos++;
        end
        if (ciclos >= 300) begin
            $display(" [FALHA] digitos_valid nao subiu!");
            col_matriz = 4'b1111;
            repeat(20) @(posedge clk);
        end else begin
            erros_b = 0;
            for (int i = 0; i < 20; i++)
                if (digitos_value[i*4 +: 4] !== 4'hB) erros_b++;
            if (digitos_valid && erros_b == 0)
                $display(" [SUCESSO] Barramento com 0xB e valid ativo!");
            else
                $display(" [FALHA] digitos_valid=%0b erros_barramento_B=%0d", digitos_valid, erros_b);

            col_matriz = 4'b1111;
            @(negedge digitos_valid);
            $display(" [OK] Borda de descida de valid detectada!");
            repeat(5) @(posedge clk);

            erros_f = 0;
            for (int i = 0; i < 20; i++)
                if (digitos_value[i*4 +: 4] !== 4'hF) erros_f++;
            if (erros_f == 0)
                $display(" [SUCESSO] Barramento retornou para 0xF!");
            else
                $display(" [FALHA] %0d posicao(oes) nao estao em 0xF.", erros_f);
        end
        linha(1);

        fazer_reset();
        n_digitos = $urandom_range(1, 19);
        $display(" Caso 2: Menos de 20 digitos (%0d digito(s))", n_digitos);
        linha(0);
        for (int k = 0; k < n_digitos; k++) begin
            gerar_num_aleatorio(digito_aleatorio);
            pressionar_digito(digito_aleatorio);
        end
        $display(" Barramento antes do #: %20h", digitos_value);

        while (lin_matriz !== 4'b1110) @(posedge clk);
        col_matriz = 4'b1101;
        ciclos = 0;
        while (!digitos_valid && ciclos < 300) begin
            @(posedge clk);
            ciclos++;
        end
        if (ciclos >= 300) begin
            $display(" [FALHA] digitos_valid nao subiu!");
            col_matriz = 4'b1111;
            repeat(20) @(posedge clk);
        end else begin
            erros_b = 0;
            for (int i = 0; i < 20; i++)
                if (digitos_value[i*4 +: 4] !== 4'hB) erros_b++;
            if (digitos_valid && erros_b == 0)
                $display(" [SUCESSO] Barramento com 0xB e valid ativo!");
            else
                $display(" [FALHA] digitos_valid=%0b erros_barramento_B=%0d", digitos_valid, erros_b);

            col_matriz = 4'b1111;
            @(negedge digitos_valid);
            $display(" [OK] Borda de descida de valid detectada!");
            repeat(5) @(posedge clk);

            erros_f = 0;
            for (int i = 0; i < 20; i++)
                if (digitos_value[i*4 +: 4] !== 4'hF) erros_f++;
            if (erros_f == 0)
                $display(" [SUCESSO] Barramento retornou para 0xF!");
            else
                $display(" [FALHA] %0d posicao(oes) nao estao em 0xF.", erros_f);
        end
        linha(1);

        fazer_reset();
        n_digitos = $urandom_range(20, 30);
        $display(" Caso 3: 20 ou mais digitos (%0d digito(s))", n_digitos);
        linha(0);
        for (int k = 0; k < n_digitos; k++) begin
            gerar_num_aleatorio(digito_aleatorio);
            pressionar_digito(digito_aleatorio);
        end
        $display(" Barramento antes do #: %20h", digitos_value);

        while (lin_matriz !== 4'b1110) @(posedge clk);
        col_matriz = 4'b1101;
        ciclos = 0;
        while (!digitos_valid && ciclos < 300) begin
            @(posedge clk);
            ciclos++;
        end
        if (ciclos >= 300) begin
            $display(" [FALHA] digitos_valid nao subiu!");
            col_matriz = 4'b1111;
            repeat(20) @(posedge clk);
        end else begin
            erros_b = 0;
            for (int i = 0; i < 20; i++)
                if (digitos_value[i*4 +: 4] !== 4'hB) erros_b++;
            if (digitos_valid && erros_b == 0)
                $display(" [SUCESSO] Barramento com 0xB e valid ativo!");
            else
                $display(" [FALHA] valid=%0b erros_barramento_B=%0d", digitos_valid, erros_b);

            col_matriz = 4'b1111;
            @(negedge digitos_valid);
            $display(" [OK] Borda de descida de valid detectada!");
            repeat(5) @(posedge clk);

            erros_f = 0;
            for (int i = 0; i < 20; i++)
                if (digitos_value[i*4 +: 4] !== 4'hF) erros_f++;
            if (erros_f == 0)
                $display(" [SUCESSO] Barramento retornou para 0xF!");
            else
                $display(" [FALHA] %0d posicao(oes) nao estao em 0xF.", erros_f);
        end

        linha(1);
    endtask

    // ================================================================
    // CENARIO 9 — Timeout de digitação
    // ================================================================
    task teste_timeout_digitacao;
        logic [3:0] t_random1, t_random2;
        logic [3:0] tecla, tecla2;
        logic [7:0] coords;
        logic [3:0] l, c;

        $display("          CENARIO 9: Timeout de Digitacao");
        linha(1);

        // ------------------------------------------------------------
        // Teste 01: Digitar proxima tecla dentro de 5 segundos
        // ------------------------------------------------------------
        
        gerar_num_aleatorio(t_random1);
        gerar_num_aleatorio(t_random2);
        
        $display(" [Teste 01] Digitando dentro do limite de 5s (Teclas: %X e %X)...", t_random1, t_random2);
        fazer_reset();
        enable = 1;
        
        pressionar_digito(t_random1);
        repeat(`MAX_ESPERA) @(posedge clk);
        
        #4900; 
        
        pressionar_digito(t_random2);
                
        if (digitos_value.digits[0] === t_random2 && digitos_valid === 1'b0) begin
            $display(" [OK] Teste 01 Passou: Digito 0x%X registrado e valid permaneceu em 0.", t_random2);
        end else begin
            $display(" [FALHA] Teste 01: Esperado digito=0x%X e valid=0. Obtido: digito=0x%X, valid=%1b", 
                     t_random2, digitos_value.digits[0], digitos_valid);
        end

        linha(0);
        
        // ------------------------------------------------------------
        // Teste 02: Nao digitar por mais de 5 segundos (Tempo Mínimo Garantido)
        // ------------------------------------------------------------
        gerar_num_aleatorio(tecla);
        $display(" [Teste 02] Digitando acima do limite de 5s (Teclas: %X)...", tecla);
        fazer_reset();
        enable = 1;
        
        pressionar_digito(tecla);
        $display("  Tecla %X pressionada. Verificando estabilidade por 5000 ciclos...", tecla);
        
        begin : bloco_verificacao_timeout
            logic tempo_atingido;
            logic falha_precoce;
            
            tempo_atingido = 0;
            falha_precoce   = 0;

            fork
                begin
                    repeat(5000) @(posedge clk);
                    tempo_atingido = 1;
                end
                
                begin
                    @(posedge digitos_valid);
                    if (!tempo_atingido) begin
                        falha_precoce = 1;
                    end
                end
            join_any
            
            if (falha_precoce) begin
                $display(" [FALHA] Teste 02: O sinal digitos_valid subiu ANTES dos 5000 pulsos mínimos!");
                $finish;
            end
            
            if (!digitos_valid) begin
                fork
                    begin : espera_pulso_final
                        wait(digitos_valid == 1'b1);
                    end
                    begin : trava_seguranca
                        repeat(100) @(posedge clk); 
                    end
                join_any
                disable fork;
            end
        end
        
        #1; 

        if (digitos_value === {20{4'hE}} && digitos_valid === 1'b1) begin
            $display(" [OK] Teste 02 (Parte 1): Timeout detectado no tempo correto! Barramento: 0xE e valid=1.");
        end else begin
            $display(" [FALHA] Teste 02 (Parte 1): Barramento nao respondeu ao timeout apos os 5000 ciclos.");
            $display("        Obtido: %20h, valid=%1b", digitos_value, digitos_valid);
            $finish; 
        end
        
        @(posedge clk);
        #1; 
        
        $display("  Barramento apos proxima borda: %20h", digitos_value);

        if (digitos_value === {20{4'hF}} && digitos_valid === 1'b0) begin
            $display(" [OK] Teste 02 (Parte 2): Sistema resetado para 0xF e valid retornou para 0.");
        end else begin
            $display(" [FALHA] Teste 02 (Parte 2): Sistema nao limpou pos-timeout. Obtido: %20h, valid=%1b", 
                     digitos_value, digitos_valid);
        end

        linha(0);

        // ------------------------------------------------------------
        // Teste 03: Com enable=0, o timer de timeout deve congelar
        // ------------------------------------------------------------
        gerar_num_aleatorio(t_random1);
        $display(" [Teste 03] Testando congelamento do Timer com enable=0 apos tecla %X...", t_random1);
        fazer_reset();
        enable = 1;
        
        pressionar_digito(t_random1);
        repeat(`MAX_ESPERA) @(posedge clk);
        
        // --- PARTE 1 ---
        repeat(3000) @(posedge clk);
        enable = 0; 
        
        $display("  -> Desativando enable e aguardando 4000 ciclos. O valid NÃO pode subir aqui.");
        fork
            begin
                wait(digitos_valid == 1'b1);
            end
            begin
                repeat(4000) @(posedge clk);
            end
        join_any
        disable fork;
        #1;

        if (digitos_valid === 1'b1 || digitos_value === {20{4'hE}}) begin
            $display(" [FALHA] Teste: Timeout disparou incorretamente com enable=0!");
            $finish;
        end else begin
            $display(" [OK] Teste 03 (Parte 1): Timer congelou com sucesso durante enable=0.");
        end
        
        // --- PARTE 2 ---
        enable = 1;
        $display("  -> Reativando enable por 1500 ciclos. Ainda nao deve dar timeout.");
        fork
            begin
                wait(digitos_valid == 1'b1);
            end
            begin
                repeat(1500) @(posedge clk);
            end
        join_any
        disable fork;
        #1;
        
        if (digitos_valid === 1'b1) begin
            $display(" [FALHA] Teste: Timeout disparou antes dos 5s totais ativos (4.5s acumulados)!");
            $finish;
        end else begin
            $display(" [OK] Teste 03 (Parte 2): Sistema acumulou 4.5s ativos sem disparar prematuramente.");
        end
        
        // --- PARTE 3 ---
        $display("  -> Forçando ciclos finais para estourar o limite acumulado...");
        fork
            begin
                wait(digitos_valid == 1'b1);
            end
            begin
                repeat(550) @(posedge clk);
            end
        join_any
        disable fork;
        #1;
        
        if (digitos_value === {20{4'hE}} && digitos_valid === 1'b1) begin
            $display(" [OK] Teste 03 (Parte 3): Timeout disparou corretamente apos somar os 5s com enable=1!");
        end else begin
            $display(" [FALHA] Teste 03 (Parte 3): Timeout nao disparou apos o tempo acumulado legítimo. Obtido: %20h", digitos_value);
            $finish;
        end

        @(posedge clk);
        #1;

        linha(1);
        $display(" [SUCESSO] Todos os testes de Timeout de digitacao e Enable passaram!");
        linha(1);
    endtask

    // ================================================================
    // CENARIO 10 — Verificação do sinal Enable
    // ================================================================
    task teste_enable;
        logic [3:0] t_rand1, t_rand2, t_rand3;
        digitosPac_t sequencia_esperada;

        $display("            CENÁRIO 10: SINAL ENABLE");
        linha(1);

        // ------------------------------------------------------------
        // Teste 01: Com enable=1, o modulo le e processa normalmente
        // ------------------------------------------------------------
        $display(" [Teste 01] Verificando operacao normal com enable=1...");
        fazer_reset();
        enable = 1;
        sequencia_esperada = ~0; 

        gerar_num_aleatorio(t_rand1);
        gerar_num_aleatorio(t_rand2);
        gerar_num_aleatorio(t_rand3);

        $display(" -> Digitando sequencia randomica: %X, %X, %X", t_rand1, t_rand2, t_rand3);
        
        pressionar_digito(t_rand1);
        repeat(`MAX_ESPERA) @(posedge clk);
        sequencia_esperada = (sequencia_esperada << 4) | t_rand1;
        
        pressionar_digito(t_rand2);
        repeat(`MAX_ESPERA) @(posedge clk);
        sequencia_esperada = (sequencia_esperada << 4) | t_rand2; 
        
        pressionar_digito(t_rand3);
        repeat(`MAX_ESPERA) @(posedge clk);
        sequencia_esperada = (sequencia_esperada << 4) | t_rand3;

        #1; 

        if (digitos_value == sequencia_esperada) begin
            $display(" [OK] Teste 01: Teclas registradas normalmente. Barramento: %20h", digitos_value);
        end else begin
            $display(" [FALHA] Teste 01: Esperado %20h, Obtido %20h", sequencia_esperada, digitos_value);
            $finish;
        end

        linha(0);

        // ------------------------------------------------------------
        // Teste 02: Com enable=0, o modulo congela e ignora entradas
        // ------------------------------------------------------------
        gerar_num_aleatorio(t_rand1);
        gerar_num_aleatorio(t_rand2);
        $display(" [Teste 02] Desativando enable=0 e testando rejeicao de tecla...");
        fazer_reset();
        enable = 1;

        pressionar_digito(t_rand1);
        repeat(`MAX_ESPERA) @(posedge clk);
        sequencia_esperada = (~0 << 4) | t_rand1; 

        enable = 0;
        repeat(5) @(posedge clk); 

        $display(" -> Módulo desativado (enable=0). Tentando forçar tecla %X...", t_rand2);
        
        fork
            begin
                pressionar_digito(t_rand2);
            end
            begin
                repeat(300) @(posedge clk);
            end
        join_any
        disable fork; 
        
        col_matriz = 4'b1111; 
        #1;                   

        if (digitos_value == sequencia_esperada) begin
            $display(" [OK] Teste 02: Módulo ignorou entradas de forma estavel e manteve valor anterior: %20h", digitos_value);
        end else begin
            $display(" [FALHA] Teste 02: O barramento mudou/corrompeu com enable=0! Obtido: %20h", digitos_value);
            $finish;
        end

        linha(0);

        // ------------------------------------------------------------
        // Teste 03: Reativar enable=1 mantem o estado anterior e retoma
        // ------------------------------------------------------------
        gerar_num_aleatorio(t_rand1);
        gerar_num_aleatorio(t_rand2);
        $display(" [Teste 03] Reativando enable=1 e verificando continuidade...");
        fazer_reset();
        enable = 1;

        pressionar_digito(t_rand1);
        repeat(`MAX_ESPERA) @(posedge clk);
        sequencia_esperada = (~0 << 4) | t_rand1;

        enable = 0;
        repeat(50) @(posedge clk);

        enable = 1;
        repeat(10) @(posedge clk); 

        $display(" -> Módulo reativado. Digitando segunda tecla: %X", t_rand2);
        pressionar_digito(t_rand2);
        repeat(`MAX_ESPERA) @(posedge clk);
        
        sequencia_esperada = (sequencia_esperada << 4) | t_rand2;
        #1; 

        if (digitos_value == sequencia_esperada) begin
            $display(" [OK] Teste 03: Varredura retomada e estado preservado perfeitamente! Barramento: %20h", digitos_value);
        end else begin
            $display(" [FALHA] Teste 03: Estado perdido ou varredura nao retomou.");
            $display("        Esperado: %20h", sequencia_esperada);
            $display("        Obtido:   %20h", digitos_value);
            $finish;
        end

        linha(1);
        $display(" [SUCESSO] Todos os testes do sinal ENABLE passaram!");
        linha(1);
    endtask

    // ================================================================
    // CENARIO 11 — Verificação do sinal de Reset
    // ================================================================
    task teste_reset;
        logic [3:0] t_rand1, t_rand2;
        digitosPac_t sequencia_esperada;

        $display("             CENÁRIO 11: SINAL DE RESET");
        linha(1);

        // ------------------------------------------------------------
        // Teste 01: Reset durante a digitação normal (Interrupção)
        // ------------------------------------------------------------
        $display(" [Teste 01] Aplicando Reset no meio da digitacao...");
        fazer_reset();
        enable = 1;

        gerar_num_aleatorio(t_rand1);
        $display(" -> Digitando tecla %X e aplicando reset imediatamente...", t_rand1);

        pressionar_digito(t_rand1); 

        gerar_num_aleatorio(t_rand2);
        $display(" -> Digitando tecla %X e aplicando reset imediatamente...", t_rand2);
        
        fork
            begin
                pressionar_digito(t_rand2);
                repeat(10) @(posedge clk); 
                rst = 1;                   
                @(posedge clk);
                rst = 0;
            end
        join

        if (digitos_value == {20{4'hF}} && digitos_valid === 1'b0) begin
            $display(" [OK] Teste 01: O sistema limpou os dados e interrompeu a digitacao com sucesso.");
        end else begin
            $display(" [FALHA] Teste 01: Sistema nao resetou corretamente em atividade. Obtido: %20h, valid=%1b", 
                     digitos_value, digitos_valid);
        end

        linha(0);

        // ------------------------------------------------------------
        // Teste 02: Reset durante o estado de erro por Timeout
        // ------------------------------------------------------------
        $display(" [Teste 02] Aplicando Reset durante o estado de Timeout (Erro)...");
        fazer_reset();
        enable = 1;

        gerar_num_aleatorio(t_rand1);
        pressionar_digito(t_rand1);

        $display(" -> Aguardando o estouro do Timeout...");
        @(posedge digitos_valid); 
        
        if (digitos_value == {20{4'hE}} && digitos_valid === 1'b1) begin
            $display(" -> Timeout detectado. Ativando sinal de Reset...");
            rst = 1;
            @(posedge clk);
            #1; 
            
            if (digitos_value == {20{4'hF}} && digitos_valid === 1'b0) begin
                $display(" [OK] Teste 02: O Reset limpou com sucesso o estado de erro de Timeout.");
            end else begin
                $display(" [FALHA] Teste 02: Reset falhou em limpar o Timeout. Obtido: %20h, valid=%1b", 
                         digitos_value, digitos_valid);
            end
            rst = 0; 
        end else begin
            $display(" [AVISO] Nao foi possivel testar: o circuito nao gerou o estado de timeout esperado.");
        end

        linha(0);

        // ------------------------------------------------------------
        // Teste 03: Reset com o módulo desativado (Enable = 0)
        // ------------------------------------------------------------
        $display(" [Teste 03] Aplicando Reset com o modulo desativado (Enable=0)...");
        fazer_reset();
        enable = 1;

        gerar_num_aleatorio(t_rand1);
        pressionar_digito(t_rand1); 

        enable = 0; 
        repeat(10) @(posedge clk);

        $display(" -> Ativando Reset com Enable=0...");
        rst = 1;
        repeat(5) @(posedge clk);
        #1;

        if (digitos_value == {20{4'hF}} && digitos_valid === 1'b0) begin
            $display(" [OK] Teste 03: Reset possui prioridade sobre o Enable e limpou o barramento.");
        end else begin
            $display(" [FALHA] Teste 03: O sinal de Enable=0 bloqueou o Reset! Obtido: %20h", digitos_value);
        end
        rst = 0;

        linha(0);

        // ------------------------------------------------------------
        // Teste 04: Manutenção do Reset ativo (Estado estático)
        // ------------------------------------------------------------
        $display(" [Teste 04] Verificando se o sistema permanece resetado com rst=1 ativo por muito tempo...");
        fazer_reset(); 
        enable = 1;
        rst = 1;       

        $display(" -> Forcando pulsos no teclado com reset ativo...");
        fork
            begin
                logic [7:0] coords;
                gerar_num_aleatorio(t_rand1);
                coords = get_coords(t_rand1);
                
                col_matriz = coords[3:0];   
                repeat(100) @(posedge clk); 
                col_matriz = 4'b1111;       
                repeat(50) @(posedge clk);
            end
        join 
        #1;

        if (digitos_value == {20{4'hF}} && digitos_valid === 1'b0) begin
            $display(" [OK] Teste 04: Sistema permaneceu imune a entradas com o Reset ativo.");
        end else begin
            $display(" [FALHA] Teste 04: O circuito aceitou dados ou mudou de estado com o Reset travado em 1! Obtido: %20h", digitos_value);
            $finish;
        end

        rst = 0; 
        repeat(10) @(posedge clk);

        linha(1);
        $display(" [SUCESSO] Todos os testes do sinal de RESET passaram!");
        linha(1);
    endtask

    // ================================================================
    // Bloco principal
    // ================================================================

    initial begin
        integer seed;
        if (!$value$plusargs("seed=%d", seed))
            seed = 42;

        void'($urandom(seed));
        if (`DEBUG) $display("=== SEMENTE ALEATORIA ATIVADA: %0d ===", seed);

        $dumpfile("teste_teclado.vcd");
        $dumpvars(0, tb_teclado);

        linha(1);
        $display("        TESTES DO TECLADO MATRICIAL 4X4        ");
        linha(1);
        $display("              INICIO DA SIMULACAO              ");
        linha(1);

        // ------ Cenario 1: Decodificacao do teclado ------
        teste_decodificar_teclado();

        // ------ Cenario 2: Shift do barramento ------
        teste_shift_barramento();

        // ------ Cenario 3: Debounce ------
        teste_debounce();

        // ------ Cenario 4: Repeticao automatica ------
        teste_repeticao_tecla();

        // ------ Cenario 5: Confirmacao com * ------
        teste_confirmacao_asterisco();

        // ------ Cenario 6: Preenchimento com F ------
        teste_preenchimento_F();

        // ------ Cenario 7: Limpeza do barramento ------
        teste_limpeza_barramento();

        // ------ Cenario 8: Tecla # ------
        teste_hashtag();

        // ------ Cenário 9: Timeout de digitação -----
        teste_timeout_digitacao();

        // ------ Cenário 10: Enable -----
        teste_enable();

        // ------ Cenário 11; Reset -----
        teste_reset();

        repeat(10) @(posedge clk);

        $display("                FIM DA SIMULACAO");
        linha(1);
        $finish;
    end

endmodule