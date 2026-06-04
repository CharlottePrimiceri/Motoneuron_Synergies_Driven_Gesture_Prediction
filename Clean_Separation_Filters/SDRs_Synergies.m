% build_sdrs_and_synergies.m
% Costruisce la SDR per tutte le MU, esporta i plot diagnostici (Spikes + SDR), 
% normalizza i dati ed esegue l'estrazione e la visualizzazione delle sinergie.

clear;
close all;
clc;

%% ========================================================================
% 1. CARICAMENTO DATI E CONFIGURAZIONE PARAMETRI
%% ========================================================================
% Caricamento del file contenente i risultati riapplicati
sig = load("D:\MUedit-main\FUNZIONI_PULIZIA_MU_FINALE\04_final_MU_sets_crosscorr\results_R2D");

reapplied = sig.reapplied;
signal = sig.signal;
fs = double(signal.fsamp);

% Definizione dei 27 periodi isometrici reali (Inizio e Fine in secondi)
periods = [
     1.51,   5.50;   9.53,  14.41;  14.68,  19.54;  23.42,  26.98;
    28.68,  33.45;  37.58,  42.48;  42.82,  47.51;  51.50,  56.56;
    56.98,  61.68;  65.58,  70.67;  70.97,  75.58;  79.44,  84.42;
    86.29,  89.42;  93.59,  98.39;  99.29, 103.37; 107.25, 111.45;
   112.78, 117.39; 121.64, 126.44; 126.85, 131.40; 135.61, 140.61;
   140.88, 145.44; 149.38, 154.41; 154.83, 159.38; 163.66, 168.36;
   168.65, 173.38; 177.30, 182.44; 182.88, 186.99
];

% Configurazione del Filtro Passa-Basso per il calcolo della SDR (Negro et al., 2016)
cutoff_freq = 2.5; % Frequenza di taglio a 2.5 Hz per estrarre la modulazione neurale lenta
filter_order = 4;
[b, a] = butter(filter_order, cutoff_freq / (fs / 2), 'low');

min_spikes_threshold = 20; % Soglia minima di attività biologica della MU

%% ========================================================================
% 2. CREAZIONE DELLE CARTELLE DI OUTPUT
%% ========================================================================
outFolder = fullfile(pwd, 'SDR_results_concat');
plotFolder = fullfile(outFolder, 'SDR_MU_Plots'); % Cartella specifica per i plot delle MU

if ~exist(outFolder, 'dir'), mkdir(outFolder); end
if ~exist(plotFolder, 'dir'), mkdir(plotFolder); end

%% ========================================================================
% 3. ELAZIONE E GENERAZIONE PLOT DIAGNOSTICI DELLE SDR
%% ========================================================================
all_SDR_raw = [];
all_SDR_norm = [];
all_firings = [];
MU_metadata = struct('grid', {}, 'mu_in_grid', {}, 'nspikes', {});

% Loop sequenziale sulle Griglie Elettrodiche e sulle singole Unità Motorie
for g = 1:size(reapplied.Dischargetimes, 1)
    if ~iscell(reapplied.Pulsetrain) || length(reapplied.Pulsetrain) < g || isempty(reapplied.Pulsetrain{g})
        continue;
    end
    
    PT = reapplied.Pulsetrain{g};
    nMU = size(PT, 1);
    nSamples = size(PT, 2);
    t = (0:nSamples-1) / fs;
    
    for mu = 1:nMU
        sp = [];
        try
            sp = reapplied.Dischargetimes{g, mu};
        catch
            sp = [];
        end
        
        % Scarto delle unità scarsamente attive o non valide
        if isempty(sp) || numel(sp) < min_spikes_threshold
            continue;
        end
        
        sp = sp(isfinite(sp) & sp >= 1 & sp <= nSamples);
        
        % Generazione del vettore binario degli spike (Treno di impulsi)
        fir = zeros(1, nSamples);
        fir(sp) = 1;
        
        % Calcolo della SDR grezza tramite filtraggio non distorsivo a fase zero
        SDR_raw = filtfilt(b, a, double(fir) * fs);
        SDR_raw(SDR_raw < 0) = 0; % Vincolo matematico di non-negatività della frequenza di scarica
        
        % Normalizzazione ampiezza [0, 1] per eliminare bias di frequenza nella NMF
        mx = max(SDR_raw);
        if mx > 0, SDR_norm = SDR_raw / mx; else, SDR_norm = SDR_raw; end
        
        % Stoccaggio nelle matrici globali
        all_firings = [all_firings; fir];
        all_SDR_raw = [all_SDR_raw; SDR_raw];
        all_SDR_norm = [all_SDR_norm; SDR_norm];
        
        MU_metadata(end+1).grid = g; %#ok<AGROW>
        MU_metadata(end).mu_in_grid = mu;
        MU_metadata(end).nspikes = numel(sp);
        
        % -----------------------------------------------------------------
        % GENERAZIONE E SALVATAGGIO AUTOMATICO DEL PLOT DIAGNOSTICO PER OGNI MU
        % -----------------------------------------------------------------
        fig_mu = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 900 500]);
        
        % Subplot 1 (Sopra): Treno degli Spike Discreti
        subplot(2,1,1);
        stem(t(sp), fir(sp), 'Color', [0.2 0.2 0.2], 'Marker', 'none', 'LineWidth', 1);
        title(sprintf('Analisi Diagnostica: Griglia %d - Unità Motoria %d', g, mu), 'FontSize', 11);
        ylabel('Spike Events');
        grid on; xlim([t(1) t(end)]); ylim([0 1.2]);
        set(gca, 'YTick', [0 1], 'XTickLabel', []);
        
        % Subplot 2 (Sotto): Segnale Continuo SDR
        subplot(2,1,2);
        plot(t, SDR_raw, 'b', 'LineWidth', 1.5);
        xlabel('Time (s)');
        ylabel('SDR (pps)');
        grid on; xlim([t(1) t(end)]);
        
        % Disegno delle linee verticali dei 27 periodi sui grafici della MU
        for sub = 1:2
            subplot(2,1,sub); hold on;
            yl = ylim;
            for p = 1:size(periods, 1)
                plot([periods(p,1) periods(p,1)], yl, 'g--', 'LineWidth', 0.6);
                plot([periods(p,2) periods(p,2)], yl, 'r--', 'LineWidth', 0.6);
            end
            hold off;
        end
        
        % Salvataggio dell'immagine ad alta risoluzione
        figName = sprintf('Grid_%d_MU_%02d.png', g, mu);
        saveas(fig_mu, fullfile(plotFolder, figName));
        close(fig_mu); % Chiude la figura nascosta per svuotare la memoria RAM
    end
end
fprintf('Salvate SDR ed esportati i relativi plot diagnostici per %d MU totali.\n', size(all_SDR_norm, 1));

% Salvataggio della matrice dati SDR globale
save(fullfile(outFolder, 'SDR_all_MU_concat.mat'), ...
    'all_firings', 'all_SDR_raw', 'all_SDR_norm', 'MU_metadata', 'fs', 't', '-v7.3');

%% ========================================================================
% 4. NON-NEGATIVE MATRIX FACTORIZATION (NMF) CON VALUTAZIONE R^2
%% ========================================================================
X = all_SDR_norm;
rowMax = max(X, [], 2);
keep = rowMax > 0;
X = X(keep, :);
MU_metadata = MU_metadata(keep);

% Calcolo della varianza totale dei dati originali (SDR reali delle MU)
X_mean = mean(X(:));
SS_tot = sum((X(:) - X_mean).^2);

% Definizione dei parametri richiesti
kList = 1:9;          % Numero di sinergie da testare (da 1 a 9)
nRepetitions = 10;    % 10 ripetizioni con seed differenti
maxIterations = 100;  % 100 iterazioni massime per ottimizzazione

% Strutture per salvare i risultati migliori per ciascun K
best_Wcell = cell(size(kList));
best_Hcell = cell(size(kList));
best_R2_per_K = zeros(size(kList));

fprintf('\nInizio ottimizzazione NMF (1-9 Sinergie, 10 Seed, 100 Iterazioni)...\n');

% Configurazione della struttura di controllo per le iterazioni massime
options = statset('MaxIter', maxIterations);

for ii = 1:numel(kList)
    k = kList(ii);
    
    highest_R2_in_rep = -Inf;
    optimal_W = [];
    optimal_H = [];
    
    for rep = 1:nRepetitions
        current_seed = rep * 100; 
        rng(current_seed);
        
        if k == 1
            % Per k=1 non passiamo matrici W0 e H0
            [W_tmp, H_tmp] = nnmf(X, k, ...
                'algorithm', 'mult', ...
                'options', options);
        else
            % Inizializzazione casuale non-negativa basata sul seed corretto
            W_init = rand(size(X,1), k);
            H_init = rand(k, size(X,2));
            
            % Passiamo direttamente W0 e H0, omettendo il parametro inesistente 'start'
            [W_tmp, H_tmp] = nnmf(X, k, ...
                'algorithm', 'mult', ...
                'w0', W_init, ...
                'h0', H_init, ...
                'options', options);
        end
        
        % Calcolo della matrice ricostruita e dell'R^2 globale
        Xhat = W_tmp * H_tmp;
        SS_res = sum((X(:) - Xhat(:)).^2);
        R2_current = 1 - (SS_res / SS_tot);
        
        if R2_current > highest_R2_in_rep
            highest_R2_in_rep = R2_current;
            optimal_W = W_tmp;
            optimal_H = H_tmp;
        end
    end
    
    % Tratteniamo la migliore combinazione tra le 10 ripetizioni
    best_Wcell{ii} = optimal_W;
    best_Hcell{ii} = optimal_H;
    best_R2_per_K(ii) = highest_R2_in_rep;
    
    fprintf('k=%d | Il più grande R^2 trattenuto tra le 10 ripetizioni = %f\n', k, highest_R2_in_rep);
end

% Scelta del miglior K basato sulla curva (per automazione prende il massimo)
[~, bestIdx] = max(best_R2_per_K);
bestK = kList(bestIdx);
W = best_Wcell{bestIdx};
H = best_Hcell{bestIdx};
fprintf('Best k basato sul massimo R^2 assoluto = %d (Verificare metodo a gomito graficamente)\n', bestK);

% Salvataggio dei risultati aggiornati
save(fullfile(outFolder, 'Synergy_results.mat'), ...
    'W', 'H', 'bestK', 'kList', 'best_R2_per_K', 'MU_metadata', 'X', '-v7.3');

%% ========================================================================
% PLOT DELLA CURVA A GOMITO BASATA SULL'R^2 MASSIMO TRATTENUTO
%% ========================================================================
figure('Name', 'Analisi del Gomito per la Selezione del Rango K (R^2)', 'Position', [150 150 650 450], 'Color', 'w');
plot(kList, best_R2_per_K * 100, 'o-', 'LineWidth', 2, 'Color', [0 0.5 0.3], 'MarkerFaceColor', [0 0.5 0.3]);
hold on;

plot(bestK, best_R2_per_K(kList==bestK) * 100, 'p', 'MarkerSize', 12, 'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'k');
yline(90, 'r--', 'Soglia 90% R^2', 'LineWidth', 1, 'LabelHorizontalAlignment', 'left');

grid on;
xlabel('Numero di Sinergie (k)', 'FontWeight', 'bold');
ylabel('Coefficiente di Determinazione R^2 (%)', 'FontWeight', 'bold');
title('Metodo del Gomito basato sul Massimo R^2 Trattenuto');
xticks(kList);
ylim([min(best_R2_per_K * 100)-5 105]);
set(gca, 'FontSize', 10);

%% ========================================================================
% 5. APPARATO GRAFICO DELLE SINERGIE (W ED H CON TUTTI I 27 TRATTEGGI)
%% ========================================================================
colors = lines(bestK);

% --- GRAFICO 2: Matrice dei Pesi Spaziali (W) ---
figure('Name', 'Pesi Spaziali W per Sinergia', 'Position', [100 100 1200 800], 'Color', 'w');
tiledlayout(bestK, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for s = 1:bestK
    nexttile;
    bar(W(:,s), 'FaceColor', colors(s,:), 'EdgeColor', 'none');
    grid on;
    ylabel(sprintf('Syn %d', s));
    title(sprintf('Vettore dei Pesi Spaziali (W) - Sinergia %d', s));
end
xlabel('Unità Motorie (Ordinate globalmente)');

% --- GRAFICO 3: Matrice delle Attivazioni Temporali (H) Continua con 27 Periodi ---
timeVec = t; 
figure('Name', 'Attivazioni Temporali H - 27 Periodi Isometrici', 'Position', [100 100 1200 900], 'Color', 'w');
tLayout = tiledlayout(bestK, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
for s = 1:bestK
    ax = nexttile;
    
    plot(timeVec, H(s,:), 'LineWidth', 1.4, 'Color', colors(s,:));
    hold on;
    
    yLimits = get(ax, 'YLim');
    
    for p = 1:size(periods, 1)
        t_start = periods(p, 1);
        t_end   = periods(p, 2);
        
        plot([t_start t_start], yLimits, 'g--', 'LineWidth', 0.8, 'HandleVisibility', 'off');
        plot([t_end t_end], yLimits, 'r--', 'LineWidth', 0.8, 'HandleVisibility', 'off');
        
        t_center = (t_start + t_end) / 2;
        y_text = yLimits(2) - (yLimits(2) - yLimits(1)) * 0.08;
        
        text(t_center, y_text, sprintf('#%d', p), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 7, ...
            'FontWeight', 'bold', ...
            'Color', [0.2 0.2 0.2], ...
            'BackgroundColor', [1 1 1 0.75], ...
            'HandleVisibility', 'off');
    end
    
    hold off;
    grid on;
    ylabel(sprintf('Syn %d', s));
    title(sprintf('Evoluzione Temporale dell''Attivazione (H) - Sinergia %d', s));
    xlim([timeVec(1) timeVec(end)]);
end
xlabel('Time (s)');