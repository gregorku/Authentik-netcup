# Záloha a obnovení

## Co záloha obsahuje

`./scripts/backup.sh` v kontejneru:

1. ověří, že `authentik-postgresql` běží a healthcheck je `healthy`;
2. zastaví `authentik-server` a `authentik-worker`, pokud běží;
3. udělá `pg_dump -Fc` lokálním socketem uživatele `postgres` uvnitř kontejneru;
4. zkopíruje `authentik/data`, `authentik/templates` a `authentik/certs`;
5. přidá kopii runtime `.env` jako `stack.env`;
6. zapíše `manifest.txt` s časem UTC, `AUTHENTIK_IMAGE`, `AUTHENTIK_TAG`, `POSTGRES_IMAGE` a sha256 každého souboru;
7. ověří, že stage obsahuje dump, tři persistentní adresáře a použitelný `AUTHENTIK_SECRET_KEY`;
8. sbalí archiv, spočítá sidecar `.sha256`, archiv znovu rozbalí a součty i úplnost ověří;
9. spustí jen ty kontejnery Authentiku, které tento běh zastavil.

Adresář dat PostgreSQL se nekopíruje. Konzistentní obraz databáze je dump.

Kopírování souborů za běhu serveru a workeru není konzistentní s dumpem: Authentik může v tu chvíli zapisovat do `/data`. Záloha proto tyto dva kontejnery na dobu dumpu a kopírování zastaví. HTTP na `10.10.10.100:9000` v tom okně neodpovídá. PostgreSQL zůstává spuštěná. Když server nebo worker před zálohou neběžel, skript ho po sobě nespouští.

Když se kontejnery po úspěšném archivu nepodaří nastartovat, skript skončí chybou. Vypíše cestu k archivu a nehlásí dokončenou zálohu jako úspěch provozu Authentiku.

Archiv:

```text
/docker-data/backups/authentik-netcup/authentik-netcup-YYYYMMDD-HHMMSS.tar.gz
```

Tento adresář leží na disku Incus kontejneru. Sám o sobě není záloha mimo kontejner.

## Externí kopie

`BACKUP_EXTERNAL_DIR` v `.env` je prázdný, dokud není známý cíl mimo kontejner. Prázdná hodnota je platná. `backup.sh` tehdy vypíše, že archiv zůstává jen na tomto Incus kontejneru, a že to není záloha mimo kontejner.

Když je proměnná nastavená, musí to být absolutní adresář mimo Git, runtime stack, `DATA_DIR` a lokální adresář záloh. Adresář musí v okamžiku zálohy existovat. Cesta se nevymýšlí. Po kopii se sidecar součet ověří v cílovém adresáři. Když ověření selže, kopie není platná záloha. Lokální archiv tím není prohlášen za zálohu mimo kontejner.

## Obnovení

Nejdřív ověření bez zápisu:

```bash
./scripts/restore.sh \
  --archive /docker-data/backups/authentik-netcup/authentik-netcup-YYYYMMDD-HHMMSS.tar.gz \
  --confirm authentik-netcup
```

Exit code `2` znamená, že archiv, manifest, dump, persistentní adresáře i `AUTHENTIK_SECRET_KEY` sedí a persistentní data se nezměnila.

Zápis:

```bash
./scripts/restore.sh \
  --archive /docker-data/backups/authentik-netcup/authentik-netcup-YYYYMMDD-HHMMSS.tar.gz \
  --confirm authentik-netcup \
  --replace-data
```

Před `--replace-data`:

- `authentik-server` a `authentik-worker` jsou zastavené;
- `authentik-postgresql` běží a je healthy;
- `AUTHENTIK_TAG` v `.env` je stejný jako `authentik_tag` v manifestu.

`--confirm` musí být přesně `authentik-netcup`. Jiná hodnota se odmítne dřív, než se archiv rozbalí.

Neúplný archiv se odmítne dřív, než se smaže živý adresář. Kontrola požaduje neprázdný `postgresql/authentik.dump`, adresáře `authentik/data`, `authentik/templates` a `authentik/certs`, souhlasící manifest a `AUTHENTIK_SECRET_KEY`, který není prázdný, není placeholder `set_*` a má aspoň 50 znaků.

Teprve potom se do `BACKUP_LOCAL_DIR` zapíše rollback: současné tři adresáře, kopie `.env` a `pg_dump` současné databáze. Snímek se ověří. Když se ho nepodaří připravit, živá data zůstávají a obnova skončí chybou.

Po snímku skript nahradí tři adresáře, v runtime `.env` vymění jen řádek `AUTHENTIK_SECRET_KEY` a teprve potom spustí `pg_restore --clean --single-transaction`. Ostatní řádky `.env`, včetně SMTP, trusted proxy a cíle záloh, se ze `stack.env` nepřebírají. Před změnou klíče vznikne vedle `.env` záloha s právy `600`. Práva samotného `.env` se zachovají.

Úspěch se vypíše až po porovnání souborů se stage, shodě klíče a kontrole, že PostgreSQL je healthy.

Když `pg_restore` nebo následná kontrola selže, skript vrátí soubory, klíč a databázi ze snímku. I tehdy skončí chybou a snímek v `BACKUP_LOCAL_DIR` ponechá. Authentik se nespouští. Když se návrat nepodaří, skript to řekne stejně jasně, Authentik se nespouští a vypíše cestu ke snímku. Soubory a klíč z toho snímku patří zpět dřív, než se z něj znovu načte dump.

`--allow-version-mismatch` obnovu povolí i při jiném tagu. Databáze z jiné verze Authentiku pak nemusí jít zmigrovat. Bez ověřeného důvodu ho nepoužívejte. Po obnově spusťte stack se stejným `AUTHENTIK_TAG`, jaký je v manifestu.

## Test bez produkčních dat

`./scripts/test.sh --static` v dočasném adresáři ověří manifest, sidecar součet, odmítnutí archivu bez dumpu, bez persistentního adresáře, s neplatným klíčem, s upraveným souborem a s neplatným manifestem. Dál ověří, že chyba načtení databáze vrátí původní soubory a klíč, že přípravná kontrola živá data nemění, že se obnoví jen `AUTHENTIK_SECRET_KEY`, a že poškozená externí kopie neprojde ověřením. `pg_dump`, `pg_restore`, Docker ani `/docker-data` při tom nespouští.
