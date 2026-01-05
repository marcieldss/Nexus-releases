@echo off
setlocal enabledelayedexpansion

:: Relanca a partir de uma copia temporaria para evitar ser apagado pelo git clean
if /i not "%~1"=="__RUN__" (
  set "TMP_BAT=%TEMP%\\remover_fonte_repo_publico_%RANDOM%%RANDOM%.bat"
  copy /Y "%~f0" "!TMP_BAT!" >nul
  call "!TMP_BAT!" __RUN__
  exit /b !ERRORLEVEL!
)

:: === CONFIGURE AQUI O QUE FICARA NO REPO ===
:: Separe por espaco. Ex.: release metadata.json README.md
set "KEEP_PATHS=README.md remover_fonte_repo_publico.bat"

echo.
echo ============================================================
echo ATENCAO: ESTE SCRIPT VAI REESCREVER O HISTORICO DO GIT
echo e REMOVER os arquivos do codigo fonte do repo PUBLICO.
echo ============================================================
echo.

:: Garante que estamos no repo
if not exist ".git" (
  echo ERRO: Este script deve ser executado na raiz do repositorio.
  pause
  exit /b 1
)

:: Verifica se ha mudancas nao commitadas
set "DIRTY="
for /f "delims=" %%s in ('git status --porcelain') do (
  if not defined DIRTY (
    echo ATENCAO: Ha arquivos nao commitados:
    set "DIRTY=1"
  )
  echo   %%s
)
if defined DIRTY (
  echo.
  set /p DIRTY_CHOICE="Digite DESCARTAR para apagar mudancas, ou SAIR para cancelar: "
  set "DIRTY_CHOICE=!DIRTY_CHOICE: =!"
  set "DIRTY_FIRST=!DIRTY_CHOICE:~0,1!"
  if /i "!DIRTY_CHOICE!"=="DESCARTAR" (
    git reset --hard
    git clean -fd
  ) else if /i "!DIRTY_FIRST!"=="D" (
    git reset --hard
    git clean -fd
  ) else (
    echo Operacao cancelada.
    pause
    exit /b 1
  )
)

:: Descobre o branch atual
for /f "delims=" %%b in ('git rev-parse --abbrev-ref HEAD') do set "CURRENT_BRANCH=%%b"
if "%CURRENT_BRANCH%"=="" (
  echo ERRO: Nao foi possivel descobrir o branch atual.
  pause
  exit /b 1
)

echo Branch atual: %CURRENT_BRANCH%
echo Manter apenas: %KEEP_PATHS%
echo.
set /p CONFIRM="Digite SIM para continuar: "
if /i not "%CONFIRM%"=="SIM" (
  echo Operacao cancelada.
  exit /b 0
)

:: Backup temporario dos arquivos a manter
set "BACKUP_DIR=%TEMP%\\repo_keep_%RANDOM%%RANDOM%"
mkdir "%BACKUP_DIR%" >nul 2>&1

for %%p in (%KEEP_PATHS%) do (
  if exist "%%p\\*" (
    mkdir "%BACKUP_DIR%\\%%p" >nul 2>&1
    robocopy "%%p" "%BACKUP_DIR%\\%%p" /E /NFL /NDL /NJH /NJS >nul
  ) else if exist "%%p" (
    copy /Y "%%p" "%BACKUP_DIR%\\%%p" >nul
  ) else (
    echo Aviso: caminho nao encontrado e sera ignorado: %%p
  )
)

:: Garante que o proprio .bat esteja no backup quando listado em KEEP_PATHS
echo %KEEP_PATHS% | findstr /I /C:"remover_fonte_repo_publico.bat" >nul
if not errorlevel 1 (
  copy /Y "%~f0" "%BACKUP_DIR%\\remover_fonte_repo_publico.bat" >nul
)

:: Cria um novo historico (orphan) e remove tudo
git checkout --orphan clean-history >nul
git rm -rf . >nul 2>&1

:: Restaura apenas os arquivos desejados
for %%p in (%KEEP_PATHS%) do (
  if exist "%BACKUP_DIR%\\%%p\\*" (
    mkdir "%%p" >nul 2>&1
    robocopy "%BACKUP_DIR%\\%%p" "%%p" /E /NFL /NDL /NJH /NJS >nul
  ) else if exist "%BACKUP_DIR%\\%%p" (
    copy /Y "%BACKUP_DIR%\\%%p" "%%p" >nul
  )
)

git add -A
git commit -m "Public repo: keep only update artifacts"

:: Volta para o nome do branch original
git branch -M "%CURRENT_BRANCH%"

echo.
echo Enviando para o GitHub (FORCE)...
git push origin "%CURRENT_BRANCH%" --force

echo.
echo Concluido.
echo Obs: commits antigos podem ficar acessiveis por algum tempo ate o GitHub limpar.
echo Se houver Releases antigas ligadas a tags com codigo, remova ou recrie as tags.

:: Remove a copia temporaria
del /f /q "%~f0" >nul 2>&1
pause
