# Avisos de proveniência e licença

## Binários pré-compilados (`prebuilt/`)

| Ficheiro | Origem |
|---|---|
| `libperfmgr.so` | dump público de Pixel 9 Pro ("caiman") — `generic_system_google-user-16-BP4A.260205.002-14624737-release-keys` (Android 16, patch 2026-02-05) |
| `libdisppower-pixel.so` | idem |
| `pixel-power-ext-V1-ndk.so` | idem |
| `android.hardware.power-V6-ndk.so` | idem |
| `android.hardware.thermal-V1-ndk.so` | idem |
| `android.hardware.power-service.pixel-libperfmgr` | idem |
| `sendhint` | idem |
| `android.hardware.power-service.pixel.xml` | idem |
| `powerhint.pixel.json` | idem |

Repositório de origem: `gm-stuffs/google_caiman_dump` (branch = fingerprint do build).
Todos os ficheiros são verificados por SHA256 em `prebuilt/SHA256SUMS` e podem ser
reobtidos com `./tools/fetch-prebuilts.sh`.

**Estes blobs são proprietários da Google** e não fazem parte do AOSP. Estão incluídos
apenas para conveniência de utilizadores finais que já possuem um dispositivo com root.
Se redistribuir este repositório, mantenha este aviso. Remova a pasta `prebuilt/` se
preferir extrair os binários você mesmo.

## Código-fonte do módulo (`module/`, `tools/`, `build.sh`)

Escrito para este projeto. Pode ser usado e modificado livremente (estilo Apache-2.0/MIT).
O `AdpfConfig` em `module/common/adpf-config.json` é derivado do `powerhint.json` do Pixel
(parâmetros de afinação do ADPF) — propriedade Google, incluído apenas como valores de
configuração de referência.

## Agradecimentos

- AOSP / `hardware/google/pixel` (`power-libperfmgr`) — pela implementação original.
- Comunidade de dumps de dispositivos no GitHub, que permite estudar ROMs sem as extrair
  fisicamente.
