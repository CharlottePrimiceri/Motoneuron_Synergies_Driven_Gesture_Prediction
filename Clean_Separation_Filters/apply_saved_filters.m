function apply_saved_filters(decompFile, targetFile, outFile, indicesFile)
% APPLY_SAVED_FILTERS Riapplica in modo deterministico i filtri spaziali DA MUEDIT FASTICA
% congelati e validati su un nuovo segnale/trial target (es. Trial 1 completo).
%
% Sintassi:
%   apply_saved_filters(decompFile, targetFile, outFile, indicesFile)

%% ========================================================================
% CONFIG
%% ========================================================================
s = load(decompFile);       % File sorgente contenente lo stato della decomposizione (muedit)
t = load(targetFile);       % Segnale target su cui riapplicare i filtri (es. intero Trial 1)
idxData = load(indicesFile);% Tabella delle unità stabili promosse dai controlli (shared_accepted)

decomp = s.signal.decomp;
sig = t.signal;
shared_accepted = idxData.shared_accepted;


% Generazione del vettore di appartenenza dei canali per mappare la topologia
% delle griglie ed escludere i canali non validi (EMGmask)
arraynb = zeros(size(sig.data,1),1);
ch1 = 1;
for g = 1:sig.ngrid
    arraynb(ch1:ch1+length(sig.EMGmask{g})-1) = g;
    ch1 = ch1 + length(sig.EMGmask{g});
end

Pulsetrain_out = cell(1, sig.ngrid);
Dischargetimes_out = cell(sig.ngrid, 1000); % (Griglia x ID_MU)

%% ========================================================================
% PER OGNI GRIGLIA
%% ========================================================================
for g = 1:sig.ngrid
    
    % REPLICA DEL PREPROCESSING ORIGINALE
    % Isolamento dei canali della griglia corrente g ed eliminazione dei canali malati
    EMG = sig.data(arraynb==g, :);
    EMG(sig.EMGmask{g}==1, :) = [];
    % Condizionamento digitale del segnale: filtri Notch e Passa-Banda
    EMG = notchsignals(EMG, sig.fsamp);
    EMG = bandpassingals(EMG, sig.fsamp, sig.emgtype(g));
    
    % ESTENSIONE TEMPORALE
    % Conversione del problema da convolutivo a istantaneo tramite replica dei
    % canali con ritardi temporali fissati dall'exFactor originale
    exFactor = decomp.exFactor{g}; 
    eSIG = extend(EMG, exFactor);
    eSIG = demean(eSIG); % Rimozione della media (centratura dei dati)
    
    %  SBIANCAMENTO (ZCA - Zero-phase Component Analysis)
    % Estrazione e srotolamento delle matrici di whitening E (autovettori) 
    % e D (autovalori) per mantenere l'invarianza di fase e l'ancoraggio geometrico ai canali fisici
    matE = decomp.whiteningE{g};
    if iscell(matE), matE = matE{1}; end 
    
    matD = decomp.whiteningD{g};
    if iscell(matD), matD = matD{1}; end 
    
    % Generazione della matrice sbiancata wSIG proiettata nello stesso identico spazio
    [wSIG, ~, ~] = whiteesig(eSIG, matE, matD);
    
    % ESTRAZIONE MATRICE FILTRI SPAZIALI COMPLETA 
    tmpMF = decomp.MUFilters{g}; 
    while iscell(tmpMF), tmpMF = tmpMF{1}; end
    MUF = tmpMF; 
    
    % SELEZIONE FILTRATA DELLE SOLE UNITA' ACCETTATE
    % Estrazione logica delle sole MU promosse dall'analisi di stabilità per la griglia g
    mu_locali_accettate = shared_accepted.MU(shared_accepted.Grid == g);
    
    if isempty(mu_locali_accettate)
        fprintf('Nessuna MU accettata per la griglia %d, salto.\n', g);
        continue;
    end
    
    % Selezione delle corrispondenti colonne (filtri spaziali congelati) nella matrice MUFilters
    MUFilters_for_grid = MUF(:, mu_locali_accettate);
    
    %% ====================================================================
    % APPLICAZIONE DEI FILTRI SULLE SINGOLE UNITA' PROMOSSE
    %% ====================================================================
    for mu_idx = 1:size(MUFilters_for_grid, 2)
        target_mu = mu_locali_accettate(mu_idx);
        
        % PROIEZIONE LINEAR
        % Calcolo della sorgente y = w' * wSIG (potenziale continuo de-convoluto)
        Pt = MUFilters_for_grid(:, mu_idx)' * wSIG;
        
        % - POST-PROCESSING (RADDRIZZAMENTO E AMPLIFICAZIONE)
        % Applicazione della non-linearità istantanea per enfatizzare i picchi reali 
        % rispetto al rumore di fondo residuo o cross-talk
        Pt = Pt .* abs(Pt);
        
        % RACCOLTA CANDIDATI SPIKE
        % findpeaks identifica i massimi locali imponendo una distanza minima di 5 ms
        % per rispettare biologicamente il periodo di refratgarietà assoluta del motoneurone
        [~, spikes] = findpeaks(Pt, 'MinPeakDistance', round(sig.fsamp*0.005));
        
        if isempty(spikes)
            Pulsetrain_out{g}(target_mu, :) = Pt;
            Dischargetimes_out{g, target_mu} = [];
            continue;
        end
        
        % NORMALIZZAZIONE
        % Riscalo dell'ampiezza basato sulla media dei 10 picchi più alti localizzati
        normFactor = mean(maxk(Pt(spikes), min(10, numel(spikes))));
        Pt = Pt / (normFactor + (normFactor==0));
        
        % SPIKE DETECTION NON SUPERVISIONATA VIA K-MEANS (K=2) 
        % Classificazione delle ampiezze dei candidati per separare il rumore dagli impulsi reali
        [L, C] = kmeans(Pt(spikes)', 2); % L = etichette dei gruppi, C = coordinate dei due centroidi
        [~, idx] = max(C);               % Identificazione del cluster associato al centroide ad ampiezza maggiore
        distime = spikes(L==idx);        % Estrazione finale dei soli tempi di scarica (discharge times validati)
        
        
        Pulsetrain_out{g}(target_mu, :) = Pt;          % Profilo continuo (Pulse Train)
        Dischargetimes_out{g, target_mu} = distime;   % Eventi discreti (Discharge Times)
    end
end

%% ========================================================================
% SAVE
%% ========================================================================
result.signal = sig;
result.reapplied.Pulsetrain = Pulsetrain_out;
result.reapplied.Dischargetimes = Dischargetimes_out;

save(outFile, '-struct', 'result', '-v7.3');
fprintf('Applicazione filtri completata. Dati salvati in: %s\n', outFile);
end
