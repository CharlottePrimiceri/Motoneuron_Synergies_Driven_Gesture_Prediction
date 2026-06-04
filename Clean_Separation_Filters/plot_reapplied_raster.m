function plot_reapplied_raster(reappliedFile)
% Visualizza l'inviluppo del segnale EMG ed il raster plot
% dei tempi di scarica delle Unità Motorie riapplicate, evidenziando i 27 periodi.

%% 1. DEFINIZIONE DEI 27 PERIODI ISOMETRICI (Inizio e Fine in secondi)
periods = [
     1.51,   5.50;   % Periodo 1
     9.53,  14.41;   % Periodo 2
    14.68,  19.54;   % Periodo 3
    23.42,  26.98;   % Periodo 4
    28.68,  33.45;   % Periodo 5
    37.58,  42.48;   % Periodo 6
    42.82,  47.51;   % Periodo 7
    51.50,  56.56;   % Periodo 8
    56.98,  61.68;   % Periodo 9
    65.58,  70.67;   % Periodo 10
    70.97,  75.58;   % Periodo 11
    79.44,  84.42;   % Periodo 12
    86.29,  89.42;   % Periodo 13
    93.59,  98.39;   % Periodo 14
    99.29, 103.37;   % Periodo 15
   107.25, 111.45;   % Periodo 16
   112.78, 117.39;   % Periodo 17
   121.64, 126.44;   % Periodo 18
   126.85, 131.40;   % Periodo 19
   135.61, 140.61;   % Periodo 20
   140.88, 145.44;   % Periodo 21
   149.38, 154.41;   % Periodo 22
   154.83, 159.38;   % Periodo 23
   163.66, 168.36;   % Periodo 24
   168.65, 173.38;   % Periodo 25
   177.30, 182.44;   % Periodo 26
   182.88, 186.99    % Periodo 27
];

%% Config
s = load(reappliedFile);

if isfield(s, 'signal') && isfield(s, 'reapplied')
    sig = s.signal;
    dt = s.reapplied.Dischargetimes;
elseif isfield(s, 'result') 
    sig = s.result.signal;
    dt = s.result.reapplied.Dischargetimes;
else
    error('File non valido: impossibile trovare le strutture EMG/Reapplied.');
end

fs = double(sig.fsamp);
nSamples = size(sig.data, 2);
t = (0:nSamples-1) / fs;

%% 3. MAPPING DEI CANALI PER LE SINGOLE GRIGLIE
arraynb = zeros(size(sig.data,1),1);
ch1 = 1;
for g = 1:sig.ngrid
    arraynb(ch1:ch1+length(sig.EMGmask{g})-1) = g;
    ch1 = ch1 + length(sig.EMGmask{g});
end

%% 4. GRAFICO 1: PANORAMICA GLOBALE (TUTTE LE GRIGLIE INSIEME)
sigPlot = mean(abs(double(sig.data)), 1);

figure('Color','w','Name','Global EMG Inenvelope and MU Raster');

% Subplot 1: Inviluppo globale
ax1 = subplot(2,1,1);
plot(t, sigPlot, 'k', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Mean |EMG| (\muV)');
title('Inviluppo Globale del Segnale HD-EMG (Tutte le Griglie)');
grid on; axis tight;

% Subplot 2: Raster plot globale
ax2 = subplot(2,1,2);
hold on;
muCount = 0;
ytickLabels = {}; 

for g = 1:size(dt,1)
    for mu = 1:size(dt,2)
        spikes = dt{g,mu};
        if isempty(spikes), continue; end
        
        muCount = muCount + 1;
        x = double(spikes) / fs;
        y = muCount * ones(size(x));
        
        plot(x, y, '.', 'MarkerSize', 8);
        ytickLabels{muCount} = sprintf('G%d-MU%d', g, mu); %#ok<AGROW>
    end
end

xlabel('Time (s)');
ylabel('Motor Units (Grid - Original ID)');
title(sprintf('Raster Plot Globale (Totale MU Identificate: %d)', muCount));
grid on;
xlim([t(1) t(end)]);
if muCount > 0
    ylim([0.5 muCount+0.5]);
    yticks(1:muCount);
    yticklabels(ytickLabels);
    set(gca, 'FontSize', 9);
end

% Disegna le linee verticali sui subplot globali
draw_isometric_lines([ax1, ax2], periods);


%% 5. GRAFICI SATELLITE: RASTER SEPARATI PER OGNI SINGOLA GRIGLIA
for g = 1:size(dt,1)
    hasUnits = false;
    for mu = 1:size(dt,2)
        if ~isempty(dt{g,mu}), hasUnits = true; break; end
    end
    if ~hasUnits, continue; end 
    
    figure('Color','w','Name',sprintf('Grid %d Diagnostic Raster', g));
    
    % Subplot 1: Inviluppo EMG locale
    axLocal1 = subplot(2,1,1);
    gridIdx = find(arraynb == g);
    gridPlot = mean(abs(double(sig.data(gridIdx,:))), 1);
    plot(t, gridPlot, 'b', 'LineWidth', 1); 
    xlabel('Time (s)');
    ylabel('Mean |EMG| (\muV)');
    title(sprintf('Inviluppo del Segnale Muscolare - Griglia %d', g));
    grid on; axis tight;
    
    % Subplot 2: Raster plot locale
    axLocal2 = subplot(2,1,2);
    hold on;
    localMu = 0;
    localLabels = {};
    
    for mu = 1:size(dt,2)
        spikes = dt{g,mu};
        if isempty(spikes), continue; end
        
        localMu = localMu + 1;
        x = double(spikes) / fs;
        y = localMu * ones(size(x));
        
        plot(x, y, 'r.', 'MarkerSize', 8); 
        localLabels{localMu} = sprintf('MU %d', mu); %#ok<AGROW>
    end
    
    xlabel('Time (s)');
    ylabel('Motor Units Identificate');
    title(sprintf('Raster Plot delle Unità Motorie - Griglia %d', g));
    grid on;
    xlim([t(1) t(end)]);
    if localMu > 0
        ylim([0.5 localMu+0.5]);
        yticks(1:localMu);
        yticklabels(localLabels);
    end
    
    % Disegna le linee verticali sui subplot della griglia corrente
    draw_isometric_lines([axLocal1, axLocal2], periods);
end

end

%% ========================================================================
% FUNZIONE PER IL DISEGNO DELLE RIGHE TRATTEGGIATE
%% ========================================================================
function draw_isometric_lines(axesHandles, periods)
% Disegna le righe tratteggiate verticali sugli assi passati come argomento
% e aggiunge la numerazione dei periodi in alto.

for ax = axesHandles
    hold(ax, 'on');
    yLimits = get(ax, 'YLim');
    
    for p = 1:size(periods, 1)
        t_start = periods(p, 1);
        t_end   = periods(p, 2);
        
        % Riga verticale inizio periodo (Tratteggiata Verde)
        plot(ax, [t_start t_start], yLimits, 'g--', 'LineWidth', 0.8, 'HandleVisibility', 'off');
        
        % Riga verticale fine periodo (Tratteggiata Rossa)
        plot(ax, [t_end t_end], yLimits, 'r--', 'LineWidth', 0.8, 'HandleVisibility', 'off');
        
        % Posiziona il testo numerato al centro del periodo, vicino al bordo superiore
        t_center = (t_start + t_end) / 2;
        y_text = yLimits(2) - (yLimits(2) - yLimits(1)) * 0.07; % Spostato leggermente sotto il bordo
        text(ax, t_center, y_text, sprintf('#%d', p), ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', ...
            'FontSize', 7, ...
            'FontWeight', 'bold', ...
            'Color', [0.2 0.2 0.2], ...
            'BackgroundColor', [1 1 1 0.7], ...
            'EdgeColor', 'none', ...
            'HandleVisibility', 'off');
    end
end
end