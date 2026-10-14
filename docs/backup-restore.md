# Záloha a obnovení

## Šifrování

Trvalý archiv je soubor `tar.gz.age`. Šifruje ho [age](https://github.com/FiloSottile/age) pro veřejného příjemce `BACKUP_AGE_RECIPIENT` v runtime `.env`. Příjemce je `age1…` nebo veřejný SSH klíč.

Soukromý klíč (`AGE-SECRET-KEY-…`) do Gitu, do archivu ani do stacku nepatří. Obnova ho čte jen z `--identity`. Soubor identity musí mít mód `600` nebo `400` a nesmí ležet v Gitu, ve stacku, v `DATA_DIR` ani v lokálním adresáři záloh. `age` ho čte přes deskriptor souboru, ne jako argument příkazu.

Když je `BACKUP_AGE_RECIPIENT` prázdný, nebo když v kontejneru není příkaz `age`, `backup.sh` archiv nezapíše a tento běh není bezpečná externí záloha.

Kontrolní součet `.sha256` patří šifrovanému souboru. Nešifrovaný tar vznikne jen v dočasném adresáři `700` a po šifrování se přepíše nástrojem `shred`, pokud je k dispozici. Když se plaintext nepodaří smazat, skript neskončí jako dokončená záloha.

`umask 077` je nastavený na začátku `backup.sh` a `restore.sh`. Dump, manifest, součet, `stack.env`, `.env.tmp` a rollback se zakládají rovnou s módem `600`, adresáře s módem `700`.

## Co záloha obsahuje

`./scripts/backup.sh` v kontejneru:

1. ověří příjemce a přítomnost `age` ještě před zastavením Authentiku;
2. ověří, že `authentik-postgresql` běží a healthcheck je `healthy`;
3. zastaví `authentik-server` a `authentik-worker`, pokud běží;
4. udělá `pg_dump -Fc` lokálním socketem uživatele `postgres` uvnitř kontejneru;
5. zkopíruje `authentik/data`, `authentik/templates` a `authentik/certs`;
6. přidá kopii runtime `.env` jako `stack.env`;
7. zapíše `manifest.txt` a ověří dump, adresáře a `AUTHENTIK_SECRET_KEY`;
8. sbalí dočasný tar, rozbalí ho a znovu ověří obsah;
9. zašifruje výsledek, spočítá součet šifrovaného souboru a smaže plaintext;
10. spustí jen ty kontejnery Authentiku, které tento běh zastavil.

Adresář dat PostgreSQL se nekopíruje. Konzistentní obraz databáze je dump.

HTTP na `10.10.10.100:9000` je po dobu dumpu a kopírování nedostupné. PostgreSQL zůstává spuštěná. Když server nebo worker před zálohou neběžel, skript ho po sobě nespouští.

Archiv:

```text
/docker-data/backups/authentik-netcup/authentik-netcup-YYYYMMDD-HHMMSS.tar.gz.age
```

Tento adresář leží na disku Incus kontejneru. Ani šifrovaný soubor v něm není záloha mimo kontejner.

## Kopie na jiný adresář

`BACKUP_EXTERNAL_DIR` je prázdný, dokud není známý cíl. Prázdná hodnota je platná. Archiv pak zůstane jen v lokálním adresáři.

Když je proměnná nastavená, cesta se vezme přes `realpath`. Musí to být existující adresář mód `700`, vlastněný uživatelem, který zálohu spouští, a nesmí být v Gitu, ve stacku, v datech ani v lokálních zálohách.

Leží-li cíl na stejném souborovém systému jako lokální adresář záloh, kopie se neprovede. To není externí záloha.

Leží-li na jiném souborovém systému, součet šifrovaného archivu se ověří v cíli. Skript to označí jako ověřenou kopii na jiném souborovém systému. Nedokáže tím prokázat, že úložiště je mimo Incus kontejner, a tak to ani nepojmenuje.

## Obnovení

Nejdřív ověření bez zápisu. Součet šifrovaného souboru se kontroluje před dešifrováním:

```bash
./scripts/restore.sh \
  --archive /docker-data/backups/authentik-netcup/authentik-netcup-YYYYMMDD-HHMMSS.tar.gz.age \
  --identity /cesta/mimo/stack/authentik.agekey \
  --confirm authentik-netcup
```

Exit code `2` znamená, že šifrovaný archiv, manifest, dump, persistentní adresáře i `AUTHENTIK_SECRET_KEY` sedí a persistentní data se nezměnila.

Zápis:

```bash
./scripts/restore.sh \
  --archive /docker-data/backups/authentik-netcup/authentik-netcup-YYYYMMDD-HHMMSS.tar.gz.age \
  --identity /cesta/mimo/stack/authentik.agekey \
  --confirm authentik-netcup \
  --replace-data
```

Před `--replace-data`:

- `authentik-server` a `authentik-worker` jsou zastavené;
- `authentik-postgresql` běží a je healthy;
- `AUTHENTIK_TAG` v `.env` je stejný jako `authentik_tag` v manifestu.

`--confirm` musí být přesně `authentik-netcup`.

Po dešifrování do adresáře `700` se kontroluje neprázdný `postgresql/authentik.dump`, adresáře `authentik/data`, `authentik/templates` a `authentik/certs`, manifest a použitelný `AUTHENTIK_SECRET_KEY`. Teprve potom se do `BACKUP_LOCAL_DIR` zapíše rollback. Jakmile adresář snímku vznikne, při nečekaném konci se nesmaže. Před první `rm` živých dat je snímek ověřený a tento režim už platí.

Snímek obsahuje tři adresáře, kopii `.env` a `pg_dump` současné databáze. Pak se nahradí soubory, v `.env` jen řádek `AUTHENTIK_SECRET_KEY` a nakonec `pg_restore --single-transaction`. Ostatní řádky `.env` zůstávají. Před zápisem klíče vznikne `.env.bak-*` s módem `600`.

Úspěch se vypíše až po porovnání souborů, shodě klíče a healthy PostgreSQL. Snímek se maže až potom. Když se snímek po ověřené obnově nesmaže, úspěch se nevyhlásí.

`SIGTERM`, `SIGINT` a `SIGHUP` spustí jeden pokus o návrat, pokud už živá data mohla být změněná. Snímek zůstane. `SIGKILL` zachytit nelze: automatický návrat neproběhne a snímek zůstane na disku právě proto, aby šel návrat udělat ručně.

## Když obnova nedoběhne

Authentik nespouštějte, dokud soubory, klíč a databáze znovu nesedí.

- Skript sám vrátil stav a skončil chybou. Snímek je v `BACKUP_LOCAL_DIR/rollback.*`. Je to kopie stavu před obnovou, ne druhá šifrovaná záloha.
- Návrat selhal. Ve zprávě je cesta ke snímku. Nejdřív vraťte `authentik/data`, `templates`, `certs` a řádek `AUTHENTIK_SECRET_KEY` ze `runtime.env` ve snímku. Teprve potom načtěte `postgresql/authentik.dump` ze snímku do běžící PostgreSQL.
- `SIGKILL` uprostřed zápisu. Snímek na disku je, automatický návrat ne. Živé adresáře mohou být prázdné nebo smíchané s archivem, klíč v `.env` může být nový a databáze ještě starý, nebo naopak. Stejný ruční postup: soubory a klíč ze snímku, potom dump ze snímku. Dokud to nesedí, server a worker nechte zastavené.

Klíč a dump jsou svázané tím, že byly v jednom archivu se součty. Skript nezkouší, že klíč dešifruje řádky v databázi.

`--allow-version-mismatch` obnovu povolí i při jiném tagu. Bez ověřeného důvodu ho nepoužívejte.

## Test bez produkčních dat

`./scripts/test.sh --static` v dočasných adresářích pouští skutečné `age`, `shred`, `install` a `sha256sum`, když jsou na stroji. `pg_dump`, `pg_restore` a Docker při tom nespouští. Zastavení kontejnerů a načtení databáze jsou v příslušných testech nahrazené funkce. `SIGTERM` dostane pomocný proces, ne produkční `restore.sh`. Druhý souborový systém se nemountuje: test odmítne dva adresáře na tom, který právě běží.
