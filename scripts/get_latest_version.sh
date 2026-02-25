#!/bin/bash
# 获取库的最新版本

SCRIPTS_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPTS_ABS}/common.sh"

# ============================================
# GitHub API 获取最新版本
# ============================================
get_github_latest_version() {
    local repo=$1
    local tag_prefix=${2:-""}  # 可选：标签前缀，如 "v" 或 "release-"
    
    # 使用 GitHub API 获取最新 release
    local api_url="https://api.github.com/repos/${repo}/releases/latest"
    
    # 尝试使用 curl 或 wget
    local response=""
    if command -v curl &> /dev/null; then
        response=$(curl -sL "$api_url" 2>/dev/null)
    elif command -v wget &> /dev/null; then
        response=$(wget -qO- "$api_url" 2>/dev/null)
    else
        log_warning "需要 curl 或 wget 来获取最新版本"
        return 1
    fi
    
    if [[ -z "$response" ]]; then
        return 1
    fi
    
    # 提取 tag_name
    local version=$(echo "$response" | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [[ -z "$version" ]]; then
        # 如果没有 release，尝试获取最新 tag
        api_url="https://api.github.com/repos/${repo}/tags"
        response=""
        if command -v curl &> /dev/null; then
            response=$(curl -sL "$api_url" 2>/dev/null | head -100)
        elif command -v wget &> /dev/null; then
            response=$(wget -qO- "$api_url" 2>/dev/null | head -100)
        fi
        
        version=$(echo "$response" | grep -o '"name": *"[^"]*"' | head -1 | cut -d'"' -f4)
    fi
    
    if [[ -n "$version" ]]; then
        # 移除标签前缀
        if [[ -n "$tag_prefix" ]] && [[ "$version" == ${tag_prefix}* ]]; then
            version="${version#${tag_prefix}}"
        fi
        echo "$version"
        return 0
    fi
    
    return 1
}

# ============================================
# 获取特定库的最新版本
# ============================================
get_latest_version() {
    local lib=$1
    
    case $lib in
        openssl)
            # OpenSSL 从官网获取
            if command -v curl &> /dev/null; then
                local version=$(curl -sL "https://www.openssl.org/source/" | \
                    grep -oE 'openssl-[0-9]+\.[0-9]+\.[0-9]+[a-z]?' | \
                    sort -V | tail -1 | sed 's/openssl-//')
                if [[ -n "$version" ]]; then
                    echo "$version"
                    return 0
                fi
            fi
            ;;
            
        zlib)
            # zlib 从官网获取
            if command -v curl &> /dev/null; then
                local version=$(curl -sL "https://zlib.net/" | \
                    grep -oE 'zlib-[0-9]+\.[0-9]+\.[0-9]+' | \
                    sort -V | tail -1 | sed 's/zlib-//')
                if [[ -n "$version" ]]; then
                    echo "$version"
                    return 0
                fi
            fi
            ;;
            
        sqlite)
            # SQLite 从官网获取最新版本号
            if command -v curl &> /dev/null; then
                local version=$(curl -sL "https://www.sqlite.org/download.html" | \
                    grep -oE 'sqlite-autoconf-[0-9]+' | \
                    head -1 | sed 's/sqlite-autoconf-//')
                if [[ -n "$version" ]]; then
                    echo "$version"
                    return 0
                fi
            fi
            ;;
            
        icu)
            get_github_latest_version "unicode-org/icu" "release-"
            return $?
            ;;
            
        protobuf)
            get_github_latest_version "protocolbuffers/protobuf" "v"
            return $?
            ;;
            
        libphonenumber)
            get_github_latest_version "google/libphonenumber" "v"
            return $?
            ;;
            
        crc32c)
            get_github_latest_version "google/crc32c" ""
            return $?
            ;;
            
        xxhash)
            get_github_latest_version "Cyan4973/xxHash" "v"
            return $?
            ;;
            
        abseil)
            # Abseil 使用 LTS 标签格式：lts-YYYYMMDD.PATCH
            # 获取最新 LTS 版本
            local api_url="https://api.github.com/repos/abseil/abseil-cpp/releases/latest"
            local response=""
            if command -v curl &> /dev/null; then
                response=$(curl -sL "$api_url" 2>/dev/null)
            elif command -v wget &> /dev/null; then
                response=$(wget -qO- "$api_url" 2>/dev/null)
            fi
            
            if [[ -n "$response" ]]; then
                # 提取 tag_name，格式可能是 lts-20240116.2
                local version=$(echo "$response" | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
                if [[ -n "$version" ]] && [[ "$version" == lts-* ]]; then
                    # 移除 lts- 前缀
                    version="${version#lts-}"
                    echo "$version"
                    return 0
                fi
            fi
            
            # 如果获取失败，尝试从 tags 获取最新的 lts-* 标签
            api_url="https://api.github.com/repos/abseil/abseil-cpp/tags"
            response=""
            if command -v curl &> /dev/null; then
                response=$(curl -sL "$api_url" 2>/dev/null | head -200)
            elif command -v wget &> /dev/null; then
                response=$(wget -qO- "$api_url" 2>/dev/null | head -200)
            fi
            
            if [[ -n "$response" ]]; then
                # 查找所有 lts-* 标签，选择最新的
                local version=$(echo "$response" | grep -o '"name": *"lts-[^"]*"' | sed 's/"name": *"lts-//;s/"//' | sort -V | tail -1)
                if [[ -n "$version" ]]; then
                    echo "$version"
                    return 0
                fi
            fi
            
            return 1
            ;;
            
        re2)
            # RE2 使用日期格式的标签
            get_github_latest_version "google/re2" ""
            return $?
            ;;
            
        libevent)
            get_github_latest_version "libevent/libevent" "release-"
            return $?
            ;;
            
        lz4)
            get_github_latest_version "lz4/lz4" "v"
            return $?
            ;;
            
        snappy)
            get_github_latest_version "google/snappy" "v"
            return $?
            ;;
            
        double-conversion)
            get_github_latest_version "google/double-conversion" "v"
            return $?
            ;;
            
        tdlib)
            get_github_latest_version "tdlib/td" "v"
            return $?
            ;;
            
        *)
            log_error "未知的库: $lib"
            return 1
            ;;
    esac
    
    return 1
}

# ============================================
# 主函数
# ============================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # 直接运行此脚本时
    if [[ $# -eq 0 ]]; then
        echo "用法: $0 <库名>"
        echo ""
        echo "支持的库:"
        echo "  openssl, zlib, sqlite, icu, protobuf, libphonenumber"
        echo "  crc32c, xxhash, abseil, re2, libevent, lz4, snappy"
        echo "  double-conversion, tdlib"
        exit 1
    fi
    
    lib=$1
    version=$(get_latest_version "$lib")
    
    if [[ -n "$version" ]]; then
        echo "$version"
        exit 0
    else
        echo "❌ 无法获取 $lib 的最新版本" >&2
        exit 1
    fi
fi
