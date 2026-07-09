#!/usr/bin/env bash
set -euo pipefail

rusty_v8_dir="${1:-}"

if [ -z "$rusty_v8_dir" ]; then
  echo "usage: $0 /path/to/rusty_v8-checkout" >&2
  exit 2
fi

build_rs="$rusty_v8_dir/build.rs"

if [ ! -f "$build_rs" ]; then
  echo "not a rusty_v8 checkout: $rusty_v8_dir" >&2
  exit 2
fi

if ! grep -q 'target_arch == "riscv64"' "$build_rs"; then
  perl -0pi -e 's/(  if target_arch == "arm" \{\n.*?maybe_install_sysroot\("arm"\);\n  \}\n)/$1\n  if target_arch == "riscv64" {\n    gn_args.push(r#"target_cpu="riscv64""#.to_string());\n    gn_args.push(r#"v8_target_cpu="riscv64""#.to_string());\n    gn_args.push("treat_warnings_as_errors=false".to_string());\n    gn_args.push("use_sysroot=false".to_string());\n    gn_args.push("use_siso=false".to_string());\n    gn_args.push("use_glib=false".to_string());\n    gn_args.push("toolchain_supports_rust_thin_lto=false".to_string());\n    if let Ok(rust_sysroot) = env::var("RUST_SYSROOT_ABSOLUTE") {\n      gn_args.push(format!("rust_sysroot_absolute={rust_sysroot:?}"));\n    }\n    if let Ok(rustc_version) = env::var("RUSTC_VERSION") {\n      gn_args.push(format!("rustc_version={rustc_version:?}"));\n    }\n  }\n/s' "$build_rs"
fi

if grep -q 'enable_rust=false' "$build_rs"; then
  perl -0pi -e 's/    gn_args\.push\("enable_rust=false"\.to_string\(\)\);\n//g' "$build_rs"
fi

if ! grep -q 'use_siso=false' "$build_rs"; then
  perl -0pi -e 's/(    gn_args\.push\("use_sysroot=false"\.to_string\(\)\);\n)/$1    gn_args.push("use_siso=false".to_string());\n/s' "$build_rs"
fi

if ! grep -q 'use_glib=false' "$build_rs"; then
  perl -0pi -e 's/(    gn_args\.push\("use_siso=false"\.to_string\(\)\);\n)/$1    gn_args.push("use_glib=false".to_string());\n/s' "$build_rs"
fi

if ! grep -q 'clang_version="19"' "$build_rs"; then
  perl -0pi -e 's/(    gn_args\.push\("use_glib=false"\.to_string\(\)\);\n)/$1    gn_args.push(r#"clang_version="19""#.to_string());\n/s' "$build_rs"
fi

if ! grep -q 'gn_args.push("use_custom_libcxx=false"' "$build_rs"; then
  perl -0pi -e 's/(    gn_args\.push\("use_glib=false"\.to_string\(\)\);\n)/$1    gn_args.push("use_custom_libcxx=false".to_string());\n/s' "$build_rs"
fi

if ! grep -q 'toolchain_supports_rust_thin_lto=false' "$build_rs"; then
  perl -0pi -e 's/(    gn_args\.push\("use_glib=false"\.to_string\(\)\);\n)/$1    gn_args.push("toolchain_supports_rust_thin_lto=false".to_string());\n    if let Ok(rust_sysroot) = env::var("RUST_SYSROOT_ABSOLUTE") {\n      gn_args.push(format!("rust_sysroot_absolute={rust_sysroot:?}"));\n    }\n    if let Ok(rustc_version) = env::var("RUSTC_VERSION") {\n      gn_args.push(format!("rustc_version={rustc_version:?}"));\n    }\n/s' "$build_rs"
fi

if ! grep -q 'rust_bindgen_root=' "$build_rs"; then
  perl -0pi -e 's/(    if let Ok\(rustc_version\) = env::var\("RUSTC_VERSION"\) \{\n      gn_args\.push\(format!\("rustc_version=\{rustc_version:\?\}"\)\);\n    \}\n)/$1    if let Ok(rust_bindgen_root) = env::var("RUST_BINDGEN_ROOT") {\n      gn_args.push(format!("rust_bindgen_root={rust_bindgen_root:?}"));\n    }\n/s' "$build_rs"
fi

if ! grep -q 'if env::var("CARGO_CFG_TARGET_ARCH").unwrap() != "riscv64"' "$build_rs"; then
  perl -0pi -e 's/  download_rust_toolchain\(\);\n/  if env::var("CARGO_CFG_TARGET_ARCH").unwrap() != "riscv64" {\n    download_rust_toolchain();\n  }\n/s' "$build_rs"
fi

bindgen_runner="$rusty_v8_dir/build/rust/gni_impl/run_bindgen.py"
if [ -f "$bindgen_runner" ] && ! grep -q 'args.libclang_path + os.pathsep' "$bindgen_runner"; then
  perl -0pi -e 's/    if args\.libclang_path:\n      env\["LIBCLANG_PATH"\] = args\.libclang_path\n/    if args.libclang_path:\n      env["LIBCLANG_PATH"] = args.libclang_path\n      if sys.platform != '\''darwin'\'':\n        env["LD_LIBRARY_PATH"] = args.libclang_path + os.pathsep + env.get(\n            "LD_LIBRARY_PATH", "")\n/s' "$bindgen_runner"
fi

macros_h="$rusty_v8_dir/v8/src/base/macros.h"
if [ -f "$macros_h" ] && ! grep -q '#define __has_warning(x) 0' "$macros_h"; then
  perl -0pi -e 's/(#include "src\/base\/logging\.h"\n)/$1\n#ifndef __has_warning\n#define __has_warning(x) 0\n#endif\n/s' "$macros_h"
fi

json_stringifier="$rusty_v8_dir/v8/src/json/json-stringifier.cc"
if [ -f "$json_stringifier" ] && ! grep -q 'V8_RISCV64_DISABLE_JSON_STRINGIFIER_SIMD' "$json_stringifier"; then
  perl -0pi -e 's/#include "hwy\/highway\.h"\n/#include "hwy\/highway.h"\n\n#if defined(V8_TARGET_ARCH_RISCV64) \&\& !defined(__riscv_vector)\n#define V8_RISCV64_DISABLE_JSON_STRINGIFIER_SIMD 1\n#endif\n/s' "$json_stringifier"
  perl -0pi -e 's/  constexpr int kUseSimdLengthThreshold = 32;\n  if \(length >= kUseSimdLengthThreshold\) \{\n    return AppendStringSIMD\(chars, length, no_gc\);\n  \}\n  return AppendStringSWAR\(chars, length, 0, 0, no_gc\);\n/#if defined(V8_RISCV64_DISABLE_JSON_STRINGIFIER_SIMD)\n  return AppendStringSWAR(chars, length, 0, 0, no_gc);\n#else\n  constexpr int kUseSimdLengthThreshold = 32;\n  if (length >= kUseSimdLengthThreshold) {\n    return AppendStringSIMD(chars, length, no_gc);\n  }\n  return AppendStringSWAR(chars, length, 0, 0, no_gc);\n#endif\n/s' "$json_stringifier"
fi

json_parser="$rusty_v8_dir/v8/src/json/json-parser.cc"
if [ -f "$json_parser" ] && ! grep -q 'V8_RISCV64_DISABLE_JSON_PARSER_SIMD' "$json_parser"; then
  perl -0pi -e 's/#include "hwy\/highway\.h"\n/#include "hwy\/highway.h"\n\n#if defined(V8_TARGET_ARCH_RISCV64) \&\& !defined(__riscv_vector)\n#define V8_RISCV64_DISABLE_JSON_PARSER_SIMD 1\n#endif\n/s' "$json_parser"
  perl -0pi -e 's/JsonString JsonParser<Char>::ScanJsonString\(bool needs_internalization\) \{\n  namespace hw = hwy::HWY_NAMESPACE;\n/JsonString JsonParser<Char>::ScanJsonString(bool needs_internalization) {\n#if !defined(V8_RISCV64_DISABLE_JSON_PARSER_SIMD)\n  namespace hw = hwy::HWY_NAMESPACE;\n#endif\n/s' "$json_parser"
  perl -0pi -e 's/  \[\[maybe_unused\]\] hw::FixedTag<uint8_t, 16> tag;\n  \[\[maybe_unused\]\] const size_t stride = hw::Lanes\(tag\);\n  \[\[maybe_unused\]\] const auto mask_0x20 = hw::Set\(tag, 0x20\);\n  \[\[maybe_unused\]\] const auto mask_quote = hw::Set\(tag, '\''"'\''\);\n  \[\[maybe_unused\]\] const auto mask_backslash = hw::Set\(tag, '\''\\\\'\''\);\n/#if !defined(V8_RISCV64_DISABLE_JSON_PARSER_SIMD)\n  [[maybe_unused]] hw::FixedTag<uint8_t, 16> tag;\n  [[maybe_unused]] const size_t stride = hw::Lanes(tag);\n  [[maybe_unused]] const auto mask_0x20 = hw::Set(tag, 0x20);\n  [[maybe_unused]] const auto mask_quote = hw::Set(tag, '\''"'\'');\n  [[maybe_unused]] const auto mask_backslash = hw::Set(tag, '\''\\\\'\'');\n#endif\n/s' "$json_parser"
  perl -0pi -e 's/    if constexpr \(sizeof\(Char\) == 1\) \{\n      \/\/ SIMD fast path/    if constexpr (sizeof(Char) == 1) {\n#if !defined(V8_RISCV64_DISABLE_JSON_PARSER_SIMD)\n      \/\/ SIMD fast path/s' "$json_parser"
  perl -0pi -e 's/        break;\n      \}\n      \/\/ Scalar fallback/        break;\n      }\n#endif\n      \/\/ Scalar fallback/s' "$json_parser"
fi

string_cc="$rusty_v8_dir/v8/src/objects/string.cc"
if [ -f "$string_cc" ] && ! grep -q 'V8_RISCV64_DISABLE_STRING_SIMD' "$string_cc"; then
  perl -0pi -e 's/#include "hwy\/highway\.h"\n/#include "hwy\/highway.h"\n\n#if defined(V8_TARGET_ARCH_RISCV64) \&\& !defined(__riscv_vector)\n#define V8_RISCV64_DISABLE_STRING_SIMD 1\n#endif\n/s' "$string_cc"
  perl -0pi -e 's/  if constexpr \(sizeof\(SourceChar\) == 1\) \{\n    \/\/ SIMD fast path/  if constexpr (sizeof(SourceChar) == 1) {\n#if !defined(V8_RISCV64_DISABLE_STRING_SIMD)\n    \/\/ SIMD fast path/s' "$string_cc"
  perl -0pi -e 's/(    if \(IsLineTerminatorSequence\(data\[src_len - 1\], SourceChar\{0\}\)\) \{\n      line_ends->push_back\(src_len - 1\);\n    \}\n)  \} else \{/$1#else\n    for (int i = 0; i < src_len - 1; i++) {\n      if (IsLineTerminatorSequence(src[i], src[i + 1])) {\n        line_ends->push_back(i);\n      }\n    }\n\n    if (src_len > 0 \&\&\n        IsLineTerminatorSequence(src[src_len - 1], SourceChar{0})) {\n      line_ends->push_back(src_len - 1);\n    }\n#endif\n  } else {/s' "$string_cc"
fi

string_hasher="$rusty_v8_dir/v8/src/strings/string-hasher.cc"
if [ -f "$string_hasher" ] && ! grep -q 'V8_RISCV64_DISABLE_STRING_HASHER_SIMD' "$string_hasher"; then
  perl -0pi -e 's/#include "hwy\/highway\.h"\n#include "src\/strings\/string-hasher-inl\.h"\n/#include "hwy\/highway.h"\n#include "src\/strings\/string-hasher-inl.h"\n\n#if defined(V8_TARGET_ARCH_RISCV64) \&\& !defined(__riscv_vector)\n#define V8_RISCV64_DISABLE_STRING_HASHER_SIMD 1\n#endif\n/s' "$string_hasher"
  perl -0pi -e 's/bool IsOnly8BitSIMD\(const uint16_t\* chars, unsigned len\) \{\n  namespace hw = hwy::HWY_NAMESPACE;\n/bool IsOnly8BitSIMD(const uint16_t* chars, unsigned len) {\n#if defined(V8_RISCV64_DISABLE_STRING_HASHER_SIMD)\n  const uint16_t* end = chars + len;\n  while (chars < end) {\n    if (*chars > 0xFF) {\n      return false;\n    }\n    chars++;\n  }\n  return true;\n#else\n  namespace hw = hwy::HWY_NAMESPACE;\n/s' "$string_hasher"
  perl -0pi -e 's/(  return true;\n\}\n\}  \/\/ namespace detail\n)/  return true;\n#endif\n}\n}  \/\/ namespace detail\n/s' "$string_hasher"
fi

grep -q 'target_arch == "riscv64"' "$build_rs"
echo "patched rusty_v8 for riscv64"
