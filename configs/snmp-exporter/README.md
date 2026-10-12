# SNMP Exporter

Konfigurace projektu Monitoring-netcup pro SNMP Exporter.

---

## Struktura

```
configs/snmp-exporter/

├── auth.yml
├── build-snmp.sh
├── generate-modules.sh
├── generator/
├── modules/
└── snmp.yml
```

---

## auth.yml

Obsahuje SNMP autentizaci.

Příklad

```yaml
auths:

  public_v2:

    version: 2

    community: public
```

---

## modules/

Obsahuje jednotlivé moduly.

Každý soubor obsahuje právě jeden modul.

Příklad

```
modules/

    mikrotik.yml

    cisco-switch.yml

    cisco-poe.yml

    cisco-cpu.yml

    cisco-memory.yml
```

Tyto soubory se nikdy neupravují ve výsledném `snmp.yml`.

---

## generator/

Obsahuje pracovní adresář SNMP Generatoru.

```
generator/

    generator.yml

    mibs/

    output/
```

---

## build-snmp.sh

Sestaví výsledný `snmp.yml`.

```
auth.yml
        │
        ▼
modules/*.yml
        │
        ▼
build-snmp.sh
        │
        ▼
snmp.yml
```

---

## generate-modules.sh

Generuje jednotlivé moduly pomocí oficiálního SNMP Generatoru.

```
generator.yml
        │
        ▼
SNMP Generator
        │
        ▼
output/snmp.yml
        │
        ▼
generate-modules.sh --split
        │
        ▼
modules/
```

---

## Workflow

```
generator.yml

↓

SNMP Generator

↓

output/snmp.yml

↓

generate-modules.sh

↓

modules/

↓

build-snmp.sh

↓

snmp.yml

↓

Docker Stack

↓

SNMP Exporter

↓

Prometheus

↓

Grafana
```

---

## Nikdy neupravovat

```
snmp.yml
```

```
generator/output/snmp.yml
```

Tyto soubory jsou vždy generované.

---

## Ručně upravovat

```
auth.yml
```

```
modules/
```

```
generator/generator.yml
```

---

## Builder

```
./build-snmp.sh --check

./build-snmp.sh
```

---

## Generator

```
./generate-modules.sh --check

./generate-modules.sh --generate

./generate-modules.sh --split

./generate-modules.sh --all
```

---

## Licence

Monitoring-netcup