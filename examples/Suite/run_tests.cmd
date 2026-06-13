@echo off
REM AMI Test Suite Runner for Windows

echo ã================================================================¬
echo ¦         AMI Library Test Suite Runner                         ¦
echo L================================================================-
echo.

REM Default configuration
if "%AMI_HOST%"=="" set AMI_HOST=192.168.129.30
if "%AMI_PORT%"=="" set AMI_PORT=5038
if "%AMI_USER%"=="" set AMI_USER=plazalink
if "%AMI_PASS%"=="" set AMI_PASS=60373fa10e73c8563afd87ad025e44b7
if "%AMI_AUTH%"=="" set AMI_AUTH=plain

REM Check if binary exists
if not exist ".\ami_test_suite.exe" (
    echo Binary not found. Building...
    make
    if errorlevel 1 (
        echo Build failed!
        exit /b 1
    )
    echo.
)

REM Display configuration
echo Configuration:
echo   Host:     %AMI_HOST%:%AMI_PORT%
echo   Username: %AMI_USER%
echo   Auth:     %AMI_AUTH%
echo.

REM Run tests
echo Running tests...
echo.

.\ami_test_suite.exe --host %AMI_HOST% --port %AMI_PORT% --username %AMI_USER% --secret %AMI_PASS% --auth %AMI_AUTH% %*

set EXIT_CODE=%errorlevel%

echo.

if %EXIT_CODE%==0 (
    echo ã================================================================¬
    echo ¦  +  ALL TESTS PASSED                                          ¦
    echo L================================================================-
) else if %EXIT_CODE%==1 (
    echo ã================================================================¬
    echo ¦  -  SOME TESTS FAILED                                         ¦
    echo L================================================================-
) else (
    echo ã================================================================¬
    echo ¦  !  FATAL ERROR                                               ¦
    echo L================================================================-
)

exit /b %EXIT_CODE%