#!/usr/bin/env python3
"""
Google Drive 自动化上传与云端分发工具
Google Drive Automated Uploader & IELTS Audio Distribution Tool

功能特性:
1. 支持 OAuth 2.0 桌面端授权（一键浏览器授权，自动刷新并缓存 token.json）；
2. 支持 Service Account 服务账号密钥（service_account.json）；
3. 自动在云盘创建/定位目标文件夹 (如: /IELTS_Prep_Library/)；
4. 自动上传真题音频 (MP3) 与伴随题库 (JSON)；
5. 核心关键步骤：自动调用 API 将上传文件的权限设置为『公开只读 (anyone:reader)』，彻底解决手机端 403 权限问题；
6. 自动返回手机端可直接消费的 CDN 直链，并可一键更新 assets/cloud_manifest.json。
"""

import os
import sys
import json
import argparse
from pathlib import Path
from typing import Optional, Dict, Any, Tuple

# 延迟导入 google 库（在未安装时提供友好提示）
try:
    from google.oauth2.credentials import Credentials
    from google.auth.transport.requests import Request
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaFileUpload
    from googleapiclient.errors import HttpError
except ImportError:
    pass

# 所需权限：读写应用自身创建或管理的文件
SCOPES = ['https://www.googleapis.com/auth/drive.file']

class GoogleDriveUploader:
    def __init__(
        self,
        credentials_path: str = "scripts/credentials.json",
        token_path: str = "scripts/token.json",
        service_account_path: Optional[str] = None
    ):
        self.credentials_path = Path(credentials_path)
        self.token_path = Path(token_path)
        self.service_account_path = Path(service_account_path) if service_account_path else None
        self.service = self._authenticate()

    def _authenticate(self):
        """执行身份认证，获取 Google Drive API 客户端实例"""
        # 1. 如果提供了 Service Account 凭据
        if self.service_account_path and self.service_account_path.exists():
            from google.oauth2 import service_account
            print(f"[*] 使用 Service Account 凭据: {self.service_account_path}")
            creds = service_account.Credentials.from_service_account_file(
                str(self.service_account_path), scopes=SCOPES
            )
            return build('drive', 'v3', credentials=creds)

        # 2. 否则使用 OAuth 2.0 桌面授权流程
        creds = None
        if self.token_path.exists():
            try:
                creds = Credentials.from_authorized_user_file(str(self.token_path), SCOPES)
            except Exception as e:
                print(f"[!] 读取缓存凭据 token.json 失败: {e}")

        # 如果凭据不存在或已失效
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                print("[*] 正在刷新过期的 Access Token...")
                creds.refresh(Request())
            else:
                if not self.credentials_path.exists():
                    raise FileNotFoundError(
                        f"\n[❌ 缺少凭据文件] 未在以下路径找到 credentials.json:\n    {self.credentials_path.resolve()}\n\n"
                        f"请在 Google Cloud Console 创建 OAuth 2.0 客户端 ID (桌面端应用)，并下载为 credentials.json 放入 scripts/ 目录。\n"
                    )
                print("[*] 正在启动浏览器以进行 Google 账号一键授权...")
                flow = InstalledAppFlow.from_client_secrets_file(
                    str(self.credentials_path), SCOPES
                )
                creds = flow.run_local_server(port=0)

            # 保存授权信息供下次免登录使用
            self.token_path.parent.mkdir(parents=True, exist_ok=True)
            with open(self.token_path, 'w', encoding='utf-8') as token_file:
                token_file.write(creds.to_json())
            print(f"[+] 授权成功！凭据已缓存至: {self.token_path}")

        return build('drive', 'v3', credentials=creds)

    def get_or_create_folder(self, folder_name: str = "IELTS_Prep_Library") -> str:
        """检查并创建 Google Drive 目标文件夹"""
        query = f"name = '{folder_name}' and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
        results = self.service.files().list(q=query, fields="files(id, name)").execute()
        files = results.get('files', [])

        if files:
            folder_id = files[0]['id']
            print(f"[*] 找到已有云盘文件夹 '{folder_name}': {folder_id}")
            return folder_id

        # 创建新文件夹
        folder_metadata = {
            'name': folder_name,
            'mimeType': 'application/vnd.google-apps.folder'
        }
        folder = self.service.files().create(body=folder_metadata, fields='id').execute()
        folder_id = folder.get('id')
        print(f"[+] 成功创建云盘文件夹 '{folder_name}': {folder_id}")
        return folder_id

    def upload_file(
        self,
        local_filepath: str,
        folder_id: Optional[str] = None,
        make_public: bool = True
    ) -> Dict[str, Any]:
        """上传单个文件，并自动赋予公开查看权限以生成直链"""
        path = Path(local_filepath)
        if not path.exists():
            raise FileNotFoundError(f"本地文件不存在: {local_filepath}")

        # 确定 MIME 类型
        mime_type = "audio/mpeg" if path.suffix.lower() == ".mp3" else "application/json"
        
        file_metadata = {'name': path.name}
        if folder_id:
            file_metadata['parents'] = [folder_id]

        media = MediaFileUpload(str(path), mimetype=mime_type, resumable=True)
        print(f"\n[*] 正在上传文件至 Google Drive: {path.name} ({path.stat().st_size} 字节)...")
        
        file = self.service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id, name, size, webViewLink'
        ).execute()

        file_id = file.get('id')
        print(f"[+] 文件上传成功！File ID: {file_id}")

        # 关键步骤：设置权限为公开只读，使手机端免登录直接拉取
        if make_public:
            try:
                self.service.permissions().create(
                    fileId=file_id,
                    body={'type': 'anyone', 'role': 'reader'},
                    fields='id'
                ).execute()
                print("    - [✅ 权限配置完成] 已设为『知道链接的任何人可查看』")
            except Exception as e:
                print(f"    - [!] 设置权限警告: {e}")

        direct_download_url = f"https://drive.google.com/uc?export=download&id={file_id}"
        return {
            "file_id": file_id,
            "filename": path.name,
            "direct_url": direct_download_url,
            "view_url": file.get('webViewLink'),
            "size": file.get('size')
        }

    def sync_test_to_manifest(
        self,
        test_id: str,
        mp3_result: Dict[str, Any],
        manifest_path: str = "assets/cloud_manifest.json"
    ):
        """自动将生成的 Google Drive 直链写入 assets/cloud_manifest.json"""
        manifest_file = Path(manifest_path)
        if not manifest_file.exists():
            print(f"[!] 未找到清单文件: {manifest_path}")
            return

        with open(manifest_file, "r", encoding="utf-8") as f:
            manifest_data = json.load(f)

        updated = False
        for entry in manifest_data.get("tests", []):
            if entry.get("testId") == test_id:
                drive_url = mp3_result["direct_url"]
                urls = entry.get("audioUrls", [])
                if drive_url not in urls:
                    # 将个人 Google Drive 直链放在首位作为优选源
                    urls.insert(0, drive_url)
                    entry["audioUrls"] = urls
                    updated = True
                    print(f"[+] 已更新清单试卷 {test_id} 音频源列表 (Google Drive 优先): {drive_url}")
                break

        if updated:
            with open(manifest_file, "w", encoding="utf-8") as f:
                json.dump(manifest_data, f, ensure_ascii=False, indent=2)
            print(f"[+] 客户端清单文件已成功更新: {manifest_file}")

def main():
    parser = argparse.ArgumentParser(description="Google Drive 雅思音频自动化上传分发工具")
    parser.add_argument("filepath", nargs="?", default="", help="待上传的音频或 JSON 文件路径")
    parser.add_argument("--test-id", type=str, default="c18_t1_s1", help="对应的真题 ID (例如: c18_t1_s1)")
    parser.add_argument("--folder", type=str, default="IELTS_Prep_Library", help="云盘目标文件夹名")
    parser.add_argument("--credentials", type=str, default="scripts/credentials.json", help="OAuth 凭据路径")
    parser.add_argument("--update-manifest", action="store_true", default=True, help="是否自动更新 assets/cloud_manifest.json")
    args = parser.parse_args()

    if not args.filepath:
        args.filepath = "assets/demo/c18_t1_s1.mp3"
        print(f"[*] 默认使用内置真题音频文件: {args.filepath}")

    try:
        uploader = GoogleDriveUploader(credentials_path=args.credentials)
        folder_id = uploader.get_or_create_folder(folder_name=args.folder)
        result = uploader.upload_file(args.filepath, folder_id=folder_id, make_public=True)

        if args.update_manifest:
            uploader.sync_test_to_manifest(args.test_id, result)

        print("\n" + "=" * 65)
        print("🎉 [自动化上传与分发完成]")
        print(f"    - 文件名称: {result['filename']}")
        print(f"    - File ID: {result['file_id']}")
        print(f"    - 客户端直链: {result['direct_url']}")
        print(f"    - 网页浏览: {result['view_url']}")
        print("=" * 65 + "\n")

    except Exception as e:
        print(f"\n[❌ 发生异常] {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
