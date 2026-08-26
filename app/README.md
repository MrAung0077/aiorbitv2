# Ovexiq

## Beta Android build

Set `$token` only in your current PowerShell session. Do not put it in source
control. Then build the tester APK with:

```powershell
flutter build apk --release `
  --dart-define="APP_ENV=production" `
  --dart-define="OVEXIQ_API_BASE_URL=https://api.ovexiq.com" `
  --dart-define="OVEXIQ_BETA_ACCESS_TOKEN=$token"
```
