param(
    [Parameter(Mandatory=$true)][string]$FlutterSdk,
    [Parameter(Mandatory=$true)][string]$AndroidSdk,
    [Parameter(Mandatory=$true)][string]$JavaHome
)
$ErrorActionPreference = 'Stop'
$flutterPath = (Resolve-Path -LiteralPath $FlutterSdk).Path
$androidPath = (Resolve-Path -LiteralPath $AndroidSdk).Path
$javaPath = (Resolve-Path -LiteralPath $JavaHome).Path
foreach ($item in @("$flutterPath/bin/flutter.bat", "$androidPath/platforms/android-35/android.jar", "$javaPath/bin/java.exe")) {
    if (-not (Test-Path -LiteralPath $item)) { throw "缺少构建文件：$item" }
}
$env:JAVA_HOME = $javaPath
$env:ANDROID_HOME = $androidPath
$env:Path = "$javaPath/bin;$env:Path"
$propertiesPath = Join-Path $PSScriptRoot 'android/local.properties'
$properties = "sdk.dir=$($androidPath.Replace('\','/'))`nflutter.sdk=$($flutterPath.Replace('\','/'))`n"
[System.IO.File]::WriteAllText($propertiesPath, $properties, [System.Text.UTF8Encoding]::new($false))
Push-Location $PSScriptRoot
try {
    & "$flutterPath/bin/flutter.bat" pub get
    if ($LASTEXITCODE -ne 0) { throw '依赖安装失败' }
    & "$flutterPath/bin/flutter.bat" test test/shiye_database_test.dart
    if ($LASTEXITCODE -ne 0) { throw '数据测试失败' }
    & "$flutterPath/bin/flutter.bat" build apk --release --target lib/shiye_main.dart
    if ($LASTEXITCODE -ne 0) { throw 'APK 构建失败' }
    Write-Output "安装包：$(Join-Path $PSScriptRoot 'build/app/outputs/flutter-apk/app-release.apk')"
} finally { Pop-Location }
