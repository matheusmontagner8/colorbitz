#!/usr/bin/env bash
# Gera o pacote de release para a Google Play: build/colorbitz-release.aab,
# assinado com a chave de upload (fica FORA do repositório).
#
# Uso (Git Bash, na raiz do projeto):
#   tools/release.sh [pasta-da-chave]
# A pasta da chave (padrão ~/colorbitz-keys) precisa ter um env.sh com:
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER e _PASSWORD
# Antes de cada envio à Play, aumente version/code (e version/name) nos dois
# presets de export_presets.cfg e application/config/version no project.godot
# (tests/test_release.gd confere se estão iguais).
set -euo pipefail
cd "$(dirname "$0")/.."
KEYS="${1:-$HOME/colorbitz-keys}"
GODOT="${GODOT:-$LOCALAPPDATA/Programs/Godot/Godot_v4.7.2-stable_win64_console.exe}"
# shellcheck source=/dev/null
source "$KEYS/env.sh"
mkdir -p build
extra=()
if [ ! -d android/build ]; then
	extra+=(--install-android-build-template)  # primeira vez: modelo do Gradle
fi
"$GODOT" --headless --path . "${extra[@]}" --export-release "Android AAB" build/colorbitz-release.aab
ls -la build/colorbitz-release.aab
