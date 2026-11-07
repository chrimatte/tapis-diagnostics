# Tapis Scan

App iPhone in SwiftUI per scoprire quali interfacce Bluetooth Low Energy espone un tapis roulant e osservare la telemetria FTMS disponibile. Utile per una prima verifica di compatibilità, senza inviare comandi di movimento.

**Progetto sperimentale:** installazione su iPhone e simulazione verificate; compatibilità con tapis roulant reali ancora da verificare. L’interfaccia è in italiano.

## Cosa fa

- Scansiona dispositivi BLE con nome, identificativo locale, RSSI e orario dell’ultimo avvistamento.
- Ordina i dispositivi per intensità del segnale: mostra subito i primi cinque e raccoglie gli altri in un elenco espandibile. Richiede una selezione esplicita prima del collegamento.
- Elenca servizi e caratteristiche GATT, con proprietà numeriche.
- Sottoscrive le notifiche FTMS Treadmill Data (`1826/2ACD`).
- Mostra velocità, distanza cumulativa, inclinazione, frequenza cardiaca, energia, tempo macchina, potenza e velocità media quando ricevuti. Calcola separatamente il passo dalla velocità.
- Segnala metriche mai ricevute, non aggiornate da oltre 5 secondi e valori precedenti alla disconnessione.
- Salva ed esporta un rapporto testuale con timestamp, advertising, notifiche grezze e valori interpretati.
- Offre dati simulati attraverso lo stesso parser, senza hardware.

Un RSSI di −50 dBm è più forte di −80 dBm: **non è una misura della distanza né una prova dell’identità della macchina**. Gli identificativi Core Bluetooth sono locali, non indirizzi MAC.

## Installazione

Servono un Mac con Xcode, un iPhone con iOS 16 o successivo e il proprio account Apple per la firma. Il nucleo SwiftPM richiede Swift 6. Il progetto è stato compilato con Xcode 26.6 e SDK iOS 26.5; l’app è stata installata e aperta su iPhone 12 con iOS 26.5.2. Le versioni minime dichiarate non sono state provate fisicamente.

```sh
git clone https://github.com/chrimatte/tapis-diagnostics.git
cd tapis-diagnostics
open Tapis.xcodeproj
```

1. Seleziona lo scheme **Tapis**.
2. In **Signing & Capabilities**, seleziona il tuo Team e, se necessario, scegli un Bundle Identifier univoco.
3. Collega l’iPhone, autorizza il Mac e abilita Developer Mode se richiesto da iOS.
4. Seleziona l’iPhone come destinazione e premi **Run**. Autorizza il profilo sviluppatore e l’accesso Bluetooth se richiesto.

Il progetto non contiene certificati o un Team di firma preimpostato. Il simulatore permette di provare la UI e i dati simulati, non la scansione BLE reale. Non è disponibile una distribuzione App Store o TestFlight.

## Prima prova

L’app guida la prova con quattro passaggi numerati: scansione, selezione, verifica dati e condivisione del rapporto.

1. Vicino alla console, premi **Scansiona BLE** e confronta nome, identificativo e RSSI. Se non riesci a identificare la macchina, evita collegamenti casuali.
2. Tocca il dispositivo: la scansione termina e l’app tenta il collegamento.
3. Mantieni l’app in primo piano. Osserva se arrivano pacchetti FTMS; alcuni dati potrebbero comparire solo durante l’uso della macchina.
4. Se consentito dalla palestra, avvia il tapis dalla sua console e confronta i valori. L’app non avvia né arresta il nastro.
5. Premi **Prepara rapporto aggiornato**, poi **Condividi rapporto preparato**. La condivisione usa una copia dei dati raccolti fino alla preparazione.

Per provare senza hardware, usa **Prova dati simulati**. I valori sono esplicitamente etichettati; **Disconnetti** ferma anche la simulazione.

## Limiti e privacy

- Il collegamento audio Bluetooth non dimostra la disponibilità di telemetria BLE. L’assenza nella scansione richiede di verificare modello, modalità di associazione e tipo di Bluetooth.
- Solo FTMS Treadmill Data è interpretato; non tutti i suoi campi sono visualizzati. I servizi proprietari vengono elencati, ma non decodificati o sottoscritti automaticamente. Nessun supporto Technogym/MyRun è dichiarato.
- La velocità è riferita dalla macchina e potrebbe essere nominale o un setpoint. Distanza e tempo sono contatori della macchina, non totali di una sessione registrata dall’app. «Mai ricevuto» non significa «non supportato».
- Passando fuori dal primo piano la diagnostica disconnette il dispositivo. Non riprende automaticamente. Non sono implementati controllo remoto, allenamenti strutturati, registrazione attività o esportazione FIT: appartengono a un progetto distinto.
- Nessun backend o invio automatico. I rapporti contengono identificativi e advertising anche di dispositivi vicini: rivedili e anonimizzali prima di condividerli o allegarli a una issue pubblica.
- Ogni apertura crea un rapporto nei Documenti dell’app, accessibile tramite File/Finder. Limite di 10 MB per rapporto, segnalato dalla UI; i file precedenti non vengono cancellati automaticamente. L’anteprima mostra solo le ultime righe. Elimina manualmente i rapporti non più necessari.

## Sviluppo e verifiche

```sh
swift test
xcodebuild -project Tapis.xcodeproj -scheme Tapis -sdk iphonesimulator \
  -configuration Debug -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

Dieci test XCTest coprono parsing, campi opzionali, pacchetti troncati/malformati, valori firmati, dati non aggiornati, passo a velocità zero, RSSI non disponibile e journal. Build simulatore e build iPhone firmata verificate localmente; nessuna certificazione di conformità FTMS o accessibilità.

`Sources/TapisCore` contiene parser e modelli; `iOS` contiene trasporto BLE, simulazione e UI; `Tests` contiene fixture sintetiche. `project.yml` consente di rigenerare il progetto con `xcodegen generate`; XcodeGen non serve per aprire il progetto incluso. Nessuna dipendenza di terze parti nel pacchetto runtime.

Vedi [CONTRIBUTING.md](CONTRIBUTING.md) per convenzioni e controlli locali.

## Licenza e riferimenti

[MIT](LICENSE). Icona creata con generazione di immagini AI per questo progetto. Nessun codice degli adattatori qdomyos-zwift o di SDK Garmin è incorporato. Nessuna affiliazione con produttori di macchine fitness.

- [Apple Core Bluetooth](https://developer.apple.com/documentation/corebluetooth)
- [Bluetooth SIG Assigned Numbers](https://www.bluetooth.com/specifications/assigned-numbers/)
- [XML Treadmill Data di Bluetooth SIG, copia pubblicata](https://raw.githubusercontent.com/oesmith/gatt-xml/master/org.bluetooth.characteristic.treadmill_data.xml), consultato come riferimento del formato, non incluso nel progetto.
