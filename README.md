# Tapis — prima base diagnostica

Stato: **implementazione parziale**, non MVP completo. Nessuna prova su hardware Technogym.

## Esecuzione

`swift test` verifica il nucleo Swift su macOS. Per iPhone: installare Xcode completo, creare un progetto iOS App SwiftUI chiamato Tapis, deployment target iOS 16, sostituire il file App generato con `iOS/Diagnostics.swift`. Aggiungere in Info → Custom iOS Target Properties `NSBluetoothAlwaysUsageDescription` con testo «Legge la telemetria del tapis roulant selezionato». Scegliere il proprio team di firma e l’iPhone 12, abilitare Developer Mode quando richiesto, eseguire Run. Non aggiungere modalità background in questa fase. Il sorgente iOS non è stato compilato in questo ambiente.

## Prova sul posto

1. Annotare modello, console, firmware e versione iOS. Accertare le regole della palestra.
2. Aprire la diagnostica in primo piano, scansionare e selezionare esplicitamente la macchina. Gli identificativi Core Bluetooth sono locali, non MAC address.
3. Condividere il rapporto di advertising/GATT. Contiene identificativi anche dei dispositivi vicini: rivederlo prima di divulgarlo.
4. Le sole notifiche sottoscritte automaticamente sono FTMS Treadmill Data 1826/2ACD. Nessun comando di movimento viene scritto.
5. Avviare eventualmente il nastro dalla console secondo le normali procedure della palestra, confrontare console e notifiche, fermare dalla console.
6. Ripetere con pausa e disconnessione. Non interpretare l’assenza di BLE come incompatibilità: verificare associazione, audio/Classic e documentazione del modello.

## Componenti e limiti

- Parser FTMS con controllo dei flag, troncamenti, velocità opzionale, distanza e inclinazione firmata; campioni con origine e timestamp.
- Journal JSONL sincronizzato su disco, recupero delle righe complete; non ancora collegato alla UI.
- Diagnostica Core Bluetooth con selezione esplicita, advertising, servizi, proprietà GATT numeriche, timestamp e condivisione testuale. Log attualmente in memoria, non persistente e non limitato: usare sessioni diagnostiche brevi.
- Mancano registratore con pause/contatori, dashboard, cronologia, FIT, replay, editor e motore intervalli, controlli automatici e relativo test completo. La qualità per singola metrica resta da modellare.
- Controllo velocità, inclinazione e trasferimento programmi: **da accertare**, non implementati. Nessun protocollo proprietario è dichiarato compatibile.
- Nessuna funzione è verificata su hardware reale; parser e journal sono verificabili con fixture. Build iOS e UI non verificate.

## Riferimenti e decisioni iniziali

[Garmin FIT Swift SDK](https://github.com/garmin/fit-swift-sdk): Package.swift consultato richiede Swift 6, dichiara iOS 14 e macOS 12, dipende da swift-collections. Compatibilità teorica con iPhone 12, da verificare con toolchain Xcode. La richiesta a LICENSE ha restituito 404: licenza **non ancora verificata**, SDK non incorporato. Prima di implementare FIT leggere la licenza effettiva, fissare la revisione e seguire il [cookbook Activity](https://developer.garmin.com/fit/articles/cookbook/encoding_activity_files.html), poi decodificare con strumento indipendente verificando CRC e riepiloghi.

[qdomyos-zwift](https://github.com/cagnulein/qdomyos-zwift) e [python-pyftms](https://github.com/dudanov/python-pyftms) individuati come riferimenti; adattatori e licenze non ancora analizzati nel dettaglio. Nessun codice copiato. MyRun non prova compatibilità con la macchina della palestra; RFCOMM non va assunto accessibile da normali app iOS.

[Apple background BLE](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html): gli eventi BLE non garantiscono un timer continuamente eseguito. L’eventuale automazione iniziale deve limitarsi al primo piano e sospendersi senza ripresa automatica dopo perdita di controllo. La macchina potrebbe continuare all’ultima impostazione.

[Bluetooth SIG Assigned Numbers](https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Assigned_Numbers/out/en/index-en.html): identificativi FTMS; completare revisione della specifica normativa prima di dichiarare conformità.

## Esito verifiche locali (7 novembre 2026)

`swift test`: fallito prima dell'esecuzione dei test, linker del manifest PackageDescription con simbolo mancante. `swiftc -typecheck`: fallito per duplicazione SwiftBridging e incompatibilità dichiarata tra SDK e compilatore dei Command Line Tools. **Nessun test risulta passato**. `xcodebuild -version`: Xcode completo non selezionato, attivi soltanto Command Line Tools. Occorre ripristinare una toolchain coerente; non sono state modificate impostazioni globali del Mac. La cartella iniziale era vuota e senza repository Git: nessun diff Git o commit disponibile.

## Informazioni comunicate dall’utente

- iPhone 12 con iOS **26.5**, versione dichiarata dall’utente.
- Xcode in download; installazione e selezione della toolchain ancora da verificare.
- Technogym **Excite**, modello da identificare fra **700, 900 e 1000**, configurazione **Unity**. Generazione della console e firmware ancora sconosciuti.
- Queste informazioni non confermano FTMS, telemetria accessibile, controllo velocità/inclinazione o trasferimento programmi. Non applicare automaticamente gli adattatori MyRun.
- Alla prossima visita annotare la denominazione esatta dalla targhetta e la versione software dalla schermata informativa della console, senza modificarne le impostazioni. Non occorre condividere il numero di serie.
