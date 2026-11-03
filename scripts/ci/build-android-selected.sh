#!/usr/bin/env bash
set -euo pipefail

variant="$ANDROID_VARIANT"
format="$ANDROID_FORMAT"
abi="$ANDROID_ABI"
mode="$ANDROID_MODE"
renderer="$ANDROID_RENDERER"

case "$variant" in standard|depth3d|tv|apple-music) ;; *) echo "::error::无效版本: $variant"; exit 1 ;; esac
case "$format" in apk-split|apk-universal|aab) ;; *) echo "::error::无效产物类型"; exit 1 ;; esac
case "$abi" in arm64|arm32|x64|all) ;; *) echo "::error::无效 ABI"; exit 1 ;; esac
case "$mode" in debug|release) ;; *) echo "::error::无效编译类型"; exit 1 ;; esac
case "$renderer" in skia|impeller) ;; *) echo "::error::无效渲染引擎"; exit 1 ;; esac

if [[ "$format" == "aab" && "$mode" != "release" ]]; then
  echo "::error::AAB 只支持 release，请修改构建选项。"; exit 1
fi
if [[ "$variant" == "depth3d" || "$variant" == "apple-music" ]] && [[ "$abi" != "arm64" ]]; then
  echo "::error::3D 版和随身听兼容版当前只支持 arm64。"; exit 1
fi
if [[ "$format" == "apk-universal" && ( "$variant" == "depth3d" || "$variant" == "apple-music" ) ]]; then
  echo "::error::3D/兼容版只支持 arm64 单架构，请选择 apk-split + arm64。"; exit 1
fi
if [[ "$variant" == "depth3d" ]] && [[ ! -f android/app/src/depth3d/assets/models/depth_anything_v2_vits_q4f16.onnx ]]; then
  echo "::error::此分支缺少 3D 模型资源。"; exit 1
fi
if [[ "$#" -gt 0 && "$1" == "--check" ]]; then
  echo "构建选项通过预检：$variant $format $abi $mode $renderer"
  exit 0
fi

flavor="$variant"
if [[ "$variant" == "apple-music" ]]; then flavor=standard; fi
case "$abi" in
  arm64) target=android-arm64 ;;
  arm32) target=android-arm ;;
  x64) target=android-x64 ;;
  all) target=android-arm64,android-arm,android-x64 ;;
esac
# Universal APKs always embed all supported ABIs. The ABI picker only applies
# to split APKs and app bundles.
if [[ "$format" == "apk-universal" ]]; then
  target=android-arm64,android-arm,android-x64
fi

if [[ "$format" == "aab" ]]; then
  args=(build appbundle)
else
  args=(build apk)
fi
args+=("--$mode" --flavor "$flavor" --target-platform "$target")
if [[ "$format" == "apk-split" ]]; then args+=(--split-per-abi); fi
if [[ "$renderer" == "skia" ]]; then
  args+=(--android-project-arg=md3EnableImpeller=false)
else
  args+=(--android-project-arg=md3EnableImpeller=true)
fi
if [[ "$variant" == "tv" ]]; then args+=(--dart-define=MD3_TV=true); fi
if [[ "$variant" == "apple-music" ]]; then
  args+=(--android-project-arg=md3ApplicationId=com.apple.android.music)
fi
printf 'flutter %q ' "${args[@]}"
echo
flutter "${args[@]}"

version="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
if [[ -z "$version" ]]; then echo "::error::pubspec 缺少版本号"; exit 1; fi
mkdir -p dist/android

if [[ "$format" == "aab" ]]; then
  mapfile -d '' built < <(find build/app/outputs/bundle -type f -name '*.aab' -print0)
else
  mapfile -d '' built < <(find build/app/outputs/flutter-apk -maxdepth 1 -type f -name '*.apk' -print0)
fi
expected=1
if [[ "$format" == "apk-split" && "$abi" == "all" ]]; then expected=3; fi
if [[ "${#built[@]}" -ne "$expected" ]]; then
  echo "::error::预期 $expected 个产物，实际 ${#built[@]} 个。"
  printf '%s\n' "${built[@]}"
  exit 1
fi

for source in "${built[@]}"; do
  basename="$(basename "$source")"
  if [[ "$format" == "aab" ]]; then
    folder=bundle; suffix=bundle; extension=aab
  elif [[ "$format" == "apk-universal" ]]; then
    folder=universal; suffix=universal; extension=apk
  else
    extension=apk
    case "$basename" in
      *arm64-v8a*) folder=arm64-v8a ;;
      *armeabi-v7a*) folder=armeabi-v7a ;;
      *x86_64*) folder=x86_64 ;;
      *) echo "::error::未识别 APK ABI：$basename"; exit 1 ;;
    esac
    suffix="$folder"
  fi
  mkdir -p "dist/android/$folder"
  output="dist/android/$folder/MD3Music-$version-$variant-$mode-$suffix.$extension"
  cp "$source" "$output"
  if [[ "$extension" == "apk" ]]; then unzip -t "$output" >/dev/null; fi
  sha256sum "$output" | tee -a dist/android/SHA256SUMS.txt
done
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### MD3Music Android 自选构建"
    echo "版本：$version | 类型：$variant | 架构：$abi | 产物：$format"
    echo
    cat dist/android/SHA256SUMS.txt
  } >> "$GITHUB_STEP_SUMMARY"
fi
