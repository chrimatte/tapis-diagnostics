# Contribuire a Tapis

Branch principale: `main`. Usare branch brevi `feat/<tema>`, `fix/<tema>` o
`chore/<tema>`, con review/PR quando si collabora.

Commit: `<tipo>(<scope opzionale>): <descrizione>` (Conventional Commits).
Non includere log BLE reali, credenziali o dati personali nelle fixture.

## Controlli

- `swift test`: suite XCTest del nucleo; richiede una toolchain Swift/SDK coerente.
  La verifica iniziale è bloccata dai Command Line Tools locali, come descritto nel README.
- `git diff --cached --check`: whitespace e marcatori di conflitto aggiunti.
- Gitleaks 8.30.1: `gitleaks git --pre-commit --staged --redact=100 --no-banner .`.

L'hook versionato `.githooks/pre-commit` esegue gli ultimi due controlli senza
modificare l'indice. Installato localmente con `git config --local core.hooksPath .githooks`.
In una nuova copia, controllare prima eventuali hook esistenti; configurare questo
percorso soltanto se non si sostituiscono hook già in uso. Gitleaks deve essere disponibile
nel PATH. La suite Swift resta un comando esplicito, non un hook.

Nessun progetto Xcode è ancora presente: le istruzioni provvisorie di installazione
sono nel README. Nessun remoto GitHub è configurato; la pubblicazione è separata.
