# MGEx - Open Source Android Roblox Executor

**Source:** [ThatMG393/MGEx](https://github.com/ThatMG393/MGEx)  
**Built by:** Liang 🐉 on Ubuntu 24.04

## File Structure

```
MGEx/
├── README.md          ← This file (build + usage guide)
├── build/
│   ├── arm64-v8a/     ← For 64-bit Android (most modern phones)
│   │   └── libMGEx.so (8.9 MB)
│   └── armeabi-v7a/   ← For 32-bit Android (older phones)
│       └── libMGEx.so (7.9 MB)
└── source/            ← Full source code (C++)
```

## Cara Install di HP

### Prasyarat
- HP Android (rooted atau VirtualXposed)
- APK Roblox original
- APKTool / MT Manager

### Langkah:

1. **Download libMGEx.so** yang sesuai:
   - HP 64-bit (kebanyakan skrg) → `arm64-v8a/libMGEx.so`
   - HP 32-bit (jarang) → `armeabi-v7a/libMGEx.so`

2. **Patch APK Roblox:**
   - Buka APK Roblox pake MT Manager / APKTool
   - Copy `libMGEx.so` ke folder `lib/arm64-v8a/` (atau `armeabi-v7a/`)
   - Buka `classes.dex` → cari `com/roblox/client/ActivityNativeMain`
   - Di method `OnCreate`, tambahin:
     ```smali
     const-string v0, "MGEx"
     invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V
     ```
   - Save, recompile, sign APK
   - Install APK yang udah di-patch

3. **Atau pake VirtualXposed (lebih gampang, gak perlu root):**
   - Install VirtualXposed
   - Inject `libMGEx.so` ke dalem VX
   - Jalankan Roblox lewat VX

### Catatan Penting
- ⚠️ **Gunakan akun alt!** Executor detected sama Byfron (anti-cheat Roblox)
- Ini untuk **belajar** cara kerja injection di Android
- Source code lengkap ada di folder `source/` — pelajari sebelum make
- Aman karna kamu compile sendiri dari source → **no virus guaranteed** ✅

### Build Sendiri (Linux)
```bash
export NDK=/path/to/android-ndk-r27c
cd source
mkdir build && cd build
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-24
make -j$(nproc)
```
