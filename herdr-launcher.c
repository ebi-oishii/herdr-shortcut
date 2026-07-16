// Herdr.app のメイン実行ファイル。
// 同バンドル内の ghostty 本体を、バンドル内の専用設定ファイルで起動するだけのスタブ。
// （シェルスクリプトだと署名付きバンドルのメイン実行ファイルとして launchd に拒否されるため Mach-O にしている）
// コマンドは -e ではなく設定ファイルの command で渡す。-e だと Ghostty 1.3 の
// セキュリティ確認ダイアログ（無効化不可）が毎回出るため。
//
// 起動時に本家 /Applications/Ghostty.app が更新されていないか（サイズ+更新時刻の
// スタンプ比較）を確認し、更新されていれば build スクリプトで複製を作り直してから起動する。
#include <limits.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define SRC_GHOSTTY "/Applications/Ghostty.app/Contents/MacOS/ghostty"

static void maybe_rebuild(const char *resources) {
    // ビルド時に記録した本家バイナリのスタンプと現在値を比較
    char stamp_path[PATH_MAX];
    snprintf(stamp_path, sizeof(stamp_path), "%s/ghostty-src.stamp", resources);
    FILE *f = fopen(stamp_path, "r");
    if (f == NULL) return;
    long long size = -1, mtime = -1;
    char script[PATH_MAX] = "";
    fscanf(f, "%lld %lld\n", &size, &mtime);
    if (fgets(script, sizeof(script), f) != NULL)
        script[strcspn(script, "\n")] = '\0';
    fclose(f);

    struct stat st;
    if (stat(SRC_GHOSTTY, &st) != 0) return;  // 本家が見つからなければ現状のまま起動
    if ((long long)st.st_size == size && (long long)st.st_mtime == mtime) return;

    // 本家が更新されている → 複製を作り直す（失敗しても古いまま起動を続行）
    if (script[0] == '\0' || access(script, X_OK) != 0) return;
    char cmd[PATH_MAX + 32];
    snprintf(cmd, sizeof(cmd), "\"%s\" >/dev/null 2>&1", script);
    system(cmd);
}

int main(void) {
    char path[PATH_MAX];
    uint32_t sz = sizeof(path);
    if (_NSGetExecutablePath(path, &sz) != 0) return 1;

    char resolved[PATH_MAX];
    if (realpath(path, resolved) == NULL) return 1;

    char *slash = strrchr(resolved, '/');
    if (slash == NULL) return 1;
    *slash = '\0';  // resolved = .../Herdr.app/Contents/MacOS

    char resources[PATH_MAX];
    snprintf(resources, sizeof(resources), "%s/../Resources", resolved);
    maybe_rebuild(resources);

    char ghostty[PATH_MAX];
    char confarg[PATH_MAX + 32];
    snprintf(ghostty, sizeof(ghostty), "%s/ghostty", resolved);
    snprintf(confarg, sizeof(confarg), "--config-file=%s/herdr.conf", resources);

    char *args[] = {
        ghostty,
        "--config-default-files=false",
        confarg,
        NULL,
    };
    execv(ghostty, args);
    perror("execv ghostty");
    return 1;
}
