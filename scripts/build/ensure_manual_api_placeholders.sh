#!/bin/bash
# 按《手动编译 TDLib for HarmonyOS 详细指南》创建 API 占位符
# 用法: source ensure_manual_api_placeholders.sh
# 要求: TD_SRC 已设置

create_placeholder_header() {
    local path="$1"
    local ns="$2"
    local guard="$3"
    mkdir -p "$(dirname "$path")"
    cat > "$path" << EOF
// Auto-generated placeholder for HarmonyOS manual build. DO NOT EDIT.
#pragma once
#ifndef ${guard}
#define ${guard}
namespace td {
namespace ${ns} {
// Placeholder
}  // namespace ${ns}
}  // namespace td
#endif
EOF
}

create_placeholder_cpp() {
    local path="$1"
    local base="$2"
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "// Placeholder" "#include \"td/${base}.h\"" "" "namespace td { namespace ${base##*/} {} }" > "$path"
}

create_placeholder_hpp() {
    local path="$1"
    local base="$2"
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "// Placeholder" "#pragma once" "#include \"td/${base}.h\"" "" "namespace td { namespace ${base##*/} {} }" > "$path"
}

run() {
    [[ -z "$TD_SRC" ]] && { echo "ensure_manual_api_placeholders: TD_SRC not set" >&2; return 1; }
    local base="$TD_SRC"
    local auto="$base/td/generate/auto/td"
    local mtproto="$base/td/mtproto"
    local telegram="$base/td/telegram"

    # 1. td/mtproto
    create_placeholder_header "$mtproto/mtproto_api.h" "mtproto_api" "TD_MTPROTO_API_H"
    create_placeholder_header "$auto/mtproto/mtproto_api.h" "mtproto_api" "TD_MTPROTO_API_AUTO_H"
    create_placeholder_hpp "$auto/mtproto/mtproto_api.hpp" "mtproto/mtproto_api"
    printf '%s\n' "// Placeholder" "#include \"td/mtproto/mtproto_api.h\"" "" "namespace td { namespace mtproto_api {} }" > "$auto/mtproto/mtproto_api.cpp"

    # 2. td/telegram
    create_placeholder_header "$telegram/telegram_api.h" "telegram_api" "TD_TELEGRAM_API_H"
    create_placeholder_header "$telegram/secret_api.h" "secret_api" "TD_SECRET_API_H"
    create_placeholder_header "$telegram/td_api.h" "td_api" "TD_TD_API_H"

    create_placeholder_header "$auto/telegram/telegram_api.h" "telegram_api" "TD_TELEGRAM_API_AUTO_H"
    create_placeholder_header "$auto/telegram/secret_api.h" "secret_api" "TD_SECRET_API_AUTO_H"
    create_placeholder_header "$auto/telegram/td_api.h" "td_api" "TD_TD_API_AUTO_H"

    create_placeholder_hpp "$auto/telegram/telegram_api.hpp" "telegram/telegram_api"
    create_placeholder_hpp "$auto/telegram/secret_api.hpp" "telegram/secret_api"
    create_placeholder_hpp "$auto/telegram/td_api.hpp" "telegram/td_api"

    printf '%s\n' "// Placeholder" "#include \"td/telegram/telegram_api.h\"" "" "namespace td { namespace telegram_api {} }" > "$auto/telegram/telegram_api.cpp"
    printf '%s\n' "// Placeholder" "#include \"td/telegram/secret_api.h\"" "" "namespace td { namespace secret_api {} }" > "$auto/telegram/secret_api.cpp"
    printf '%s\n' "// Placeholder" "#include \"td/telegram/td_api.h\"" "" "namespace td { namespace td_api {} }" > "$auto/telegram/td_api.cpp"

    # 3. td_api_json
    printf '%s\n' "// Placeholder" "#include \"td/telegram/td_api.h\"" "" "namespace td { namespace td_api {} }" > "$auto/telegram/td_api_json.cpp"
    create_placeholder_header "$auto/telegram/td_api_json.h" "td_api" "TD_TD_API_JSON_H"

    # 4. td_tdc_api（tdc 库用）
    create_placeholder_header "$auto/telegram/td_tdc_api.h" "td_api" "TD_TDC_API_H"
    printf '%s\n' "// Placeholder" "#pragma once" "#include \"td/telegram/td_tdc_api.h\"" > "$auto/telegram/td_tdc_api_inner.h"
    printf '%s\n' "// Placeholder" "#include \"td/telegram/td_tdc_api.h\"" "" "namespace td { namespace td_api {} }" > "$auto/telegram/td_tdc_api.cpp"

    # 5. MIME 占位符
    local gen="$base/tdutils/generate/auto"
    mkdir -p "$gen"
    printf '%s\n' "// placeholder" "#include <cstddef>" "const char* mime_type_to_extension(const char*, size_t) { return nullptr; }" > "$gen/mime_type_to_extension.cpp"
    printf '%s\n' "// placeholder" "#include <cstddef>" "const char* extension_to_mime_type(const char*, size_t) { return nullptr; }" > "$gen/extension_to_mime_type.cpp"

    # 6. tlo 目录
    mkdir -p "$base/td/generate/auto/tlo"
    touch "$base/td/generate/auto/tlo/mtproto_api.tlo" \
          "$base/td/generate/auto/tlo/secret_api.tlo" \
          "$base/td/generate/auto/tlo/td_api.tlo" \
          "$base/td/generate/auto/tlo/telegram_api.tlo" 2>/dev/null || true

    echo "✅ API 占位符已创建 (TD_SRC=$TD_SRC)"
}

run "$@"
