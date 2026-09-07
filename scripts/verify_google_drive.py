#!/usr/bin/env python3
"""
Google Drive 雅思音频直链联通性与格式校验工具
Google Drive Audio Link Diagnostic & Verification Tool

使用方法:
    py scripts/verify_google_drive.py <Google Drive链接 或 文件ID>

示例:
    py scripts/verify_google_drive.py https://drive.google.com/file/d/1aBcDeFgHiJkLmNoPqRsTuVwXyZ/view?usp=sharing
    py scripts/verify_google_drive.py 1aBcDeFgHiJkLmNoPqRsTuVwXyZ
"""

import sys
import re
import argparse
from typing import Optional
import requests

def extract_file_id(input_str: str) -> Optional[str]:
    """从分享链接或裸字符串中提取 Google Drive File ID"""
    input_str = input_str.strip()
    
    # 匹配 /file/d/<id>/ 形式
    match = re.search(r'/file/d/([a-zA-Z0-9_-]+)', input_str)
    if match:
        return match.group(1)
    
    # 匹配 id=<id> 形式
    match = re.search(r'[?&]id=([a-zA-Z0-9_-]+)', input_str)
    if match:
        return match.group(1)
    
    # 如果纯粹是 20-60 位字母数字下划线/破折号
    if re.fullmatch(r'[a-zA-Z0-9_-]{20,60}', input_str):
        return input_str
        
    return None

def verify_google_drive_link(file_id: str) -> bool:
    print(f"\n" + "=" * 65)
    print(f"[*] 开始诊断 Google Drive 音频直链联通性")
    print(f"[*] 目标 File ID: {file_id}")
    
    direct_url = f"https://drive.google.com/uc?export=download&id={file_id}"
    print(f"[*] 构造直链 URL: {direct_url}")
    print("=" * 65)
    
    session = requests.Session()
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }

    try:
        print("\n[Step 1] 发送 HTTP GET 请求测试联通性...")
        response = session.get(direct_url, headers=headers, stream=True, timeout=15)
        
        status_code = response.status_code
        content_type = response.headers.get("Content-Type", "")
        content_length = response.headers.get("Content-Length")
        
        print(f"    - HTTP 响应码: {status_code}")
        print(f"    - 响应内容类型 (Content-Type): {content_type}")
        if content_length:
            size_mb = int(content_length) / (1024 * 1024)
            print(f"    - 文件大小 (Content-Length): {content_length} 字节 ({size_mb:.2f} MB)")
        else:
            print(f"    - 文件大小 (Content-Length): 未知 (分块传输)")
            
        if status_code != 200:
            print(f"\n[❌ 诊断失败] HTTP 请求返回非 200 状态码 ({status_code})。")
            if status_code == 404:
                print("    - 原因: 文件不存在或 File ID 错误。")
            elif status_code == 403:
                print("    - 原因: 权限受限，Google 拒绝未授权访问。")
                print("    - 解决方案: 请在 Google Drive 网页端将该文件共享权限设置为『知道链接的任何人可查看』！")
            return False

        # 读取前 1024 字节探针检测数据包格式
        chunk = next(response.iter_content(chunk_size=1024), b"")
        chunk_str = chunk.decode("utf-8", errors="ignore").lower()

        print("\n[Step 2] 数据包特征与护栏过滤检测 (Byte Sniffing)...")
        # 检测是否被 Google 拦截重定向至 HTML 确认页
        if "<!doctype html" in chunk_str or "<html" in chunk_str:
            print("[❌ 诊断失败] 响应内容为 HTML 网页，并非真正的 MP3 音频二进制流！")
            if "virus scan" in chunk_str or "quota" in chunk_str or "download_warning" in chunk_str:
                print("    - 拦截原因: 触发了 Google Drive 大文件病毒扫描提示或单日下载配额超限。")
                print("    - 规避建议: 雅思听力试卷音频（单段约 5~15MB）通常不会触发 100MB 限制。")
                print("    - 请确认文件分享权限是否为公开，或者尝试在直链中附带确认参数: &confirm=t")
            elif "sign in" in chunk_str or "accounts.google.com" in chunk_str:
                print("    - 拦截原因: 文件属于私有权限，Google 强制重定向至登录页。")
                print("    - 解决方案: 在 Google 云盘右键文件 -> 分享 -> 权限由『受限制』改为『任何拥有链接的人』。")
            return False

        # 检测是否包含音频标识 (如 ID3 头部或 MPEG 同步字)
        is_audio = False
        if chunk.startswith(b"ID3") or (len(chunk) > 2 and chunk[0] == 0xFF and (chunk[1] & 0xE0) == 0xE0):
            is_audio = True
            print("    - [✅ 音频特征确认] 检测到标准 MP3 头部特征 (ID3v2 或 MPEG Frame Sync)！")
        elif "audio" in content_type or "octet-stream" in content_type:
            is_audio = True
            print(f"    - [✅ 二进制流确认] Content-Type 为 {content_type}，非文本网页。")

        if not is_audio:
            print(f"    - [⚠️ 提示] 未检测到标准 MP3 标记，但为二进制数据 ({chunk[:10]}...)。")

        print("\n[Step 3] 模拟客户端流式下载 64KB 音频片段...")
        total_sample = len(chunk)
        for sub_chunk in response.iter_content(chunk_size=8192):
            total_sample += len(sub_chunk)
            if total_sample >= 65536:
                break
        print(f"    - 成功拉取测试样本: {total_sample} 字节，连接保持正常，无丢包。")

        print("\n" + "=" * 65)
        print("🎉 [结论: 验证通过] 此 Google Drive 直链完全通畅！")
        print(f"手机客户端 CloudSyncService 可直接将其配置于 assets/cloud_manifest.json 中:")
        print(f'    "audioUrls": [')
        print(f'      "{direct_url}"')
        print(f'    ]')
        print("=" * 65 + "\n")
        return True

    except requests.exceptions.Timeout:
        print("\n[❌ 诊断失败] 连接 Google 服务器超时 (Timeout)。")
        print("    - 请检查当前网络是否能够正常访问 Google 服务（或是否配置了代理）。")
        return False
    except requests.exceptions.RequestException as e:
        print(f"\n[❌ 诊断失败] 网络请求发生异常: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Google Drive 雅思音频直链联通性与格式校验工具")
    parser.add_argument("url_or_id", nargs="?", default="", help="Google Drive 共享链接或文件 ID")
    args = parser.parse_args()

    target = args.url_or_id
    if not target:
        print("Google Drive 音频直链诊断工具")
        print("--------------------------------------------------")
        target = input("请输入 Google Drive 音频文件分享链接或 File ID: ").strip()

    if not target:
        print("[!] 错误: 未提供链接或 File ID。")
        sys.exit(1)

    file_id = extract_file_id(target)
    if not file_id:
        print(f"[!] 错误: 无法从输入内容中解析出有效的 Google Drive File ID: {target}")
        sys.exit(1)

    success = verify_google_drive_link(file_id)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
