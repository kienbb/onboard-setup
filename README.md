# Windows Onboarding Script

Tự động cài đặt toàn bộ môi trường phát triển cho máy Windows 11.

## Cách sử dụng

### Cách 1: Chạy trực tiếp từ GitHub (Nhanh nhất)

Mở **Terminal/PowerShell với quyền Administrator**, sau đó dán lệnh:

```powershell
powershell -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/kienbb/onboard-setup/main/install.ps1' -OutFile '$env:TEMP\install.ps1'; & '$env:TEMP\install.ps1'"
```

Script sẽ tự động:
- Tải về `%TEMP%\install.ps1`
- Chạy với quyền Admin (tự relaunch nếu cần)
- Cài đặt toàn bộ và tự resume sau restart

### Cách 2: Tải script về máy trước

#### 1. Clone hoặc download repository

```bash
git clone https://github.com/kienbb/onboard-setup.git
cd onboard-setup
```

#### 2. Mở PowerShell với quyền Administrator

- Nhấn `Win + X` → chọn **Terminal (Admin)** hoặc **Windows PowerShell (Admin)**
- Hoặc: Nhấp chuột phải vào file `install.ps1` → **Run with PowerShell** (script sẽ tự động yêu cầu Admin nếu cần)

#### 3. Chạy script

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Hoặc nếu đang ở trong PowerShell Admin:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install.ps1
```

## Quy trình cài đặt

Script chạy qua **12 Phase** tự động:

| Phase | Nội dung | Tương tác |
|-------|----------|-----------|
| 0 | Bootstrap (Chocolatey, Winget) | Không |
| 1 | WSL2, IIS, Ubuntu, Dark Mode, Git config | Không |
| 2 | Kiểm tra sau restart | Không |
| 3 | Cài phần mềm (Chrome, Discord, VS Code, Node.js, ...) | Không |
| 4 | Python 3.10–3.13 qua pyenv-win | Không |
| 5 | Rust | Không |
| 6 | IIS Hosting Bundle (.NET 8, 9) | Không |
| 7 | Visual Studio Community (ASP.NET, C++, Unity) | Hiện progress UI, **không cần click** |
| 8 | OpenCode Desktop | Không |
| 9 | Claude Code CLI + OpenCode CLI | Không |
| 10 | VS Code Extension (Claude Code) | Không |
| 11 | Dọn dẹp & báo cáo | Không |

## Khởi động lại máy

Script sẽ **tự động restart máy 1 lần** sau Phase 1 (khi cài WSL2 + IIS).
- Sau restart, script tự động chạy lại và tiếp tục từ Phase 2.
- **Bạn không cần làm gì thêm.**

## Nếu script bị ngắt giữa chừng

Dù bị **mất điện, crash, hoặc đóng cửa sổ**, bạn chỉ cần:

```powershell
.\install.ps1
```

Script sẽ tự động:
- Đọc trạng thái đã lưu
- **Bỏ qua các phần mềm đã cài**
- Tiếp tục từ điểm gián đoạn

## Sau khi script hoàn tất

Các phần cần xử lý **thủ công**:

1. **Unity**: Mở Unity Hub → đăng nhập → cài Unity Editor 6000.4 + modules Android, WebGL, iOS
2. **WSL2/Ubuntu**: Nếu lần đầu khởi động Ubuntu, cần tạo username/password
3. **Restart**: Nếu có thông báo yêu cầu restart từ bất kỳ phần mềm nào

## Danh sách phần mềm được cài

### Công cụ hệ thống
- 7-Zip
- Notepad++
- Windows Terminal
- PowerToys
- Git (đã config sẵn `kiennt` / `kiennt@pixon.games`)
- WSL2 + Ubuntu

### Trình duyệt & Giao tiếp
- Google Chrome
- Discord
- Telegram Desktop

### Lập trình
- VS Code + Claude Code Extension
- Visual Studio Community 2022 (ASP.NET, Desktop C++, Unity workloads)
- Unity Hub
- Fork (Git UI)
- Postman

### Runtime & Ngôn ngữ
- Node.js LTS (bao gồm npm)
- Python 3.10, 3.11, 3.12, 3.13 (qua pyenv-win, mặc định 3.13)
- .NET SDK 8, 9 (10 nếu có sẵn)
- Rust

### Server
- IIS + ASP.NET
- IIS Hosting Bundle (.NET 8, 9)

### OpenCode & AI
- OpenCode Desktop
- OpenCode CLI (`opencode-ai`)
- Claude Code CLI (`@anthropic-ai/claude-code`)

## Troubleshooting

### Lỗi `ExecutionPolicy`
Nếu gặp lỗi chính sách thực thi:
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
```

### Winget không tìm thấy
Trên Windows 11, Winget thường đã có sẵn. Nếu thiếu, script sẽ cố cài qua Chocolatey. Nếu vẫn lỗi, cài [App Installer](https://apps.microsoft.com/detail/9NBLGGH4NNS1) từ Microsoft Store.

### Visual Studio cài lâu
Visual Studio 2022 rất nặng (15–30GB tùy workload). Phase 7 có thể mất **30–90 phút**. Progress window sẽ hiện nhưng **tự động chạy**, bạn không cần bấm gì.

### Log file
Xem chi tiết tại: `%TEMP%\onboarding.log`

## Tác giả

Script được tạo tự động cho `kiennt@pixon.games`.