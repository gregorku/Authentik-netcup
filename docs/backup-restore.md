# Záloha a obnovení

## Co záloha obsahuje

`./scripts/backup.sh` v kontejneru:

1. ověří, že `authentik-postgresql` běží a healthcheck je `healthy`;
2. udělá `pg_dump -Fc` lokálním socketem uživatele `postgres` uvnitř kontejneru;
3. zkopíruje `authentik/data`, `authentik/templates` a `authentik/certs`;
4. přidá kopii runtime `.env` jako `stack.env`;
5. zapíše `manifest.txt` s časem UTC, `AUTHENTIK_IMAGE`, `AUTHENTIK_TAG`, `POSTGRES_IMAGE` a sha256 každého souboru;
6. sbalí archiv, spočítá sidecar `.sha256` a archiv znovu rozbalí a součty ověří.

Adresář dat PostgreSQL se nekopíruje. Konzistentní obraz databáze je dump.

Archiv:

```text
/docker-data/backups/authentik-netcup/authentik-netcup-YYYYMMDD-HHMMSS.tar.gz
```

## Externí kopie

`BACKUP_EXTERNAL_DIR` v `.env` je prázdný, dokud není známý cíl mimo kontejner. Prázdná hodnota je platná. `backup.sh` tehdy vypíše, že existuje jen lokální záloha, a nikam jinam nekopíruje.

Když je proměnná nastavená, musí to být absolutní adresář mimo Git, runtime stack, `DATA_DIR` a lokální adresář záloh. Adresář musí v okamžiku zálohy existovat. Cesta se nevymýšlí.

## Obnovení

Nejdřív ověření bez zápisu:

```bash
./scripts/restore.sh \
  --archive /docker-data/backups/authentik-netcup/authentik-netcup-YYYYMMDD-HHMMSS.tar.gz \
  --confirm authentik-netcup
```

Exit code `2` znamená, že archiv i manifest sedí a persistentní data se nezměnila.

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

Pořadí zápisu je nejdřív soubory Authentiku (a `chown 1000:1000`), potom `pg_restore --clean` do běžící PostgreSQL. `stack.env` se přes runtime `.env` automaticky nekopíruje. Secret key v `.env` musí odpovídat zálohované databázi, jinak sessions a část tajemství v databázi nesedí. Porovnejte soubory ručně.

`--allow-version-mismatch` obnovu povolí i při jiném tagu. Databáze z jiné verze Authentiku pak nemusí jít zmigrovat. Bez ověřeného důvodu ho nepoužívejte. Po obnově spusťte stack se stejným `AUTHENTIK_TAG`, jaký je v manifestu.

`--confirm` musí být přesně `authentik-netcup`. Jiná hodnota se odmítne dřív, než se archiv rozbalí do dat.

## Test bez produkčních dat

`./scripts/test.sh --static` v dočasném adresáři sestaví manifest, ověří součty a odmítne upravený soubor. Volá také kontrolu `--confirm` a neshody verze. `pg_dump`, `pg_restore` ani `/docker-data` při tom nespouští.
