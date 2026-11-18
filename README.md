# Pokémon Nero Doppiato

Progetto amatoriale che aggiunge il **doppiaggio in italiano** a *Pokémon Versione Nera* (Nintendo DS).

Il pacchetto contiene l'emulatore [BizHawk](https://github.com/TASEmulators/BizHawk), uno script Lua e le registrazioni delle voci. Mentre giochi, lo script riconosce il dialogo a schermo e riproduce la voce del personaggio, bolla per bolla.

> ⚠️ **La ROM del gioco NON è inclusa.** Per giocare ti serve una copia di *Pokémon Versione Nera* che possiedi legalmente.

<!-- Inserire qui uno screenshot o una GIF del gioco con il doppiaggio (fatta da voi, senza loghi ufficiali) -->

---

## Indice

- [Requisiti](#requisiti)
- [Installazione](#installazione)
- [Come si gioca](#come-si-gioca)
- [Domande frequenti e problemi](#domande-frequenti-e-problemi)
- [Crediti](#crediti)
- [Avviso legale](#avviso-legale)

---

## Requisiti

- **Windows 10 o 11** (la riproduzione audio usa componenti di Windows).
- I **prerequisiti di BizHawk**: .NET Framework 4.8 e Visual C++ Redistributable. Se BizHawk non si avvia, installa il pacchetto *BizHawk Prerequisites* dalla [pagina delle release di BizHawk](https://github.com/TASEmulators/BizHawk/releases).
- Una ROM di **Pokémon Versione Nera in italiano** (`.nds`), ricavata dalla tua cartuccia.
  Le voci sono collegate al testo italiano del gioco: con altre lingue o con *Versione Bianca* non funzionano.

---

## Installazione

### 1. Scarica il pacchetto

Vai nella sezione [**Releases**](../../releases) di questa pagina e scarica l'ultimo file `PokemonNeroDoppiato_vX.Y.zip`.

Estrai lo zip in una cartella a tua scelta, per esempio `C:\Giochi\PokemonNeroDoppiato`.

> Evita cartelle protette come `C:\Program Files`: BizHawk deve poter scrivere i salvataggi nella sua cartella.

Dopo l'estrazione dovresti avere:

```
PokemonNeroDoppiato/
├── PokemonNeroDoppiato.bat   ← avvia il gioco
├── BizHawk/                  ← emulatore
├── ROM/                      ← qui va la tua ROM
└── scripts/                  ← script e voci (non modificare)
```

### 2. Inserisci la tua ROM

Copia la tua ROM di *Pokémon Versione Nera* nella cartella `ROM/` e **rinominala** così:

```
ROM/PokemonNero.nds
```

> Il nome deve essere esattamente `PokemonNero.nds`. Se Windows nasconde le estensioni dei file, attento a non ottenere `PokemonNero.nds.nds`.

### 3. Avvia il gioco

Fai doppio clic su **`PokemonNeroDoppiato.bat`**.

Si apre BizHawk con il gioco e lo script del doppiaggio già attivo. Si apre anche la finestra *Lua Console*: puoi ridurla a icona, ma **non chiuderla**, altrimenti il doppiaggio si ferma.

> Al primo avvio Windows potrebbe mostrare l'avviso *"Windows ha protetto il PC"*. Clicca su **Ulteriori informazioni → Esegui comunque**.

---

## Come si gioca

- Il gioco funziona come l'originale. Le voci partono da sole quando compare un dialogo doppiato.
- Premi **A** o **B** per passare alla bolla successiva: la voce di quella bolla parte e la precedente si interrompe.
- Se salti un dialogo, l'audio si ferma.
- I comandi della tastiera si cambiano in BizHawk da **Config → Controllers**.
- Il volume delle voci segue quello di Windows. Il volume del gioco si regola da **Config → Sound** in BizHawk.

### Salvataggi

Il gioco salva normalmente con il menu **Salva**. I file di salvataggio stanno nella cartella di BizHawk (`BizHawk/NDS/SaveRAM`).

Se aggiorni il pacchetto a una nuova versione, **copia quella cartella** nella nuova installazione per non perdere i progressi.

---

## Domande frequenti e problemi

**Il gioco parte ma non sento nessuna voce.**
Apri la *Lua Console* e controlla che ci sia la scritta `Pokemon Nero Doppiato avviato`. Se ci sono righe con `ERRORE`, apri una [segnalazione](../../issues) e allega il testo.
Ricorda che non tutti i dialoghi sono già doppiati: vedi [Crediti](#crediti).

**BizHawk dice che non trova la ROM.**
Controlla che il file sia in `ROM/` e si chiami esattamente `PokemonNero.nds`.

**Alcune voci partono e altre no nello stesso dialogo.**
È normale: il doppiaggio è in corso e alcune battute non sono ancora state registrate.

**Funziona con la ROM inglese / con Versione Bianca / con Nero 2?**
No. Le voci sono collegate al testo della versione italiana di *Pokémon Versione Nera*.

**Posso usare un altro emulatore?**
No. Lo script funziona solo con BizHawk.

## Crediti

### Doppiatori

| Personaggio | Voce | Stato |
|---|---|---|
| Prof. Aralia | *Nome Cognome* | 🟡 in corso |
| Komor | *Nome Cognome* | 🟡 in corso |
| Belle | *Nome Cognome* | 🟡 in corso |
| Mamma | *Nome Cognome* | 🟡 in corso |
| Ghecis | *Nome Cognome* | 🟡 in corso |
| N | *Nome Cognome* | 🟡 in corso |
| Spighetto (Capopalestra) | *Nome Cognome* | ⚪ da fare |
| Chicco (Capopalestra) | *Nome Cognome* | ⚪ da fare |
| Maisello (Capopalestra) | *Nome Cognome* | ⚪ da fare |
| Aloé (Capopalestra) | *Nome Cognome* | ⚪ da fare |
| Artemisio (Capopalestra) | *Nome Cognome* | ⚪ da fare |
| Camelia (Capopalestra) | *Nome Cognome* | ⚪ da fare |
| Rafan (Capopalestra) | *Nome Cognome* | ⚪ da fare |
| Anemone (Capopalestra) | *Nome Cognome* | ⚪ da fare |
| Silvestro (Capopalestra) | *Nome Cognome* | ⚪ da fare |
| Aristide (Capopalestra) | *Nome Cognome* | ⚪ da fare |
| Antemia (Super Quattro) | *Nome Cognome* | ⚪ da fare |
| Mirton (Super Quattro) | *Nome Cognome* | ⚪ da fare |
| Catlina (Super Quattro) | *Nome Cognome* | ⚪ da fare |
| Marzio (Super Quattro) | *Nome Cognome* | ⚪ da fare |
| Nardo | *Nome Cognome* | ⚪ da fare |
| Iris | *Nome Cognome* | ⚪ da fare |
| Camilla | *Nome Cognome* | ⚪ da fare |

🟢 completo · 🟡 in corso · ⚪ da fare

### Programmazione

- **Tiziano Bonaccorsi** ([@TizFox](https://github.com/TizFox)) – script Lua, strumenti di estrazione, ricerca in memoria e gestione audio
- **Gios** ([@gios](https://github.com/TizFox)) – organizzazione, strumenti di estrazione e formattazione del copione

### Software di terze parti

- [BizHawk](https://github.com/TASEmulators/BizHawk) – emulatore multi-sistema, distribuito con licenza MIT (vedi `BizHawk/LICENSE`).

---

## Avviso legale

Questo è un **progetto amatoriale, gratuito e non commerciale**, realizzato da fan.

- **Non è affiliato** a Nintendo, The Pokémon Company, Game Freak o Creatures Inc., né approvato da loro.
- *Pokémon* e tutti i nomi correlati sono marchi dei rispettivi proprietari.
- Il pacchetto **non contiene la ROM** né altri file del gioco. Per giocare è necessaria una copia del gioco posseduta legalmente.
- Il progetto non accetta donazioni e non ha scopo di lucro.

Se sei titolare di diritti e ritieni che questo progetto violi i tuoi diritti, contattaci tramite le [Issues](../../issues) e provvederemo a rimuovere i contenuti.
