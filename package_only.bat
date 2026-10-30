@echo off
echo Packaging Lambda function...
set PACKAGE_FILE=lambda-deployment.zip

if exist %PACKAGE_FILE% del %PACKAGE_FILE%
if exist package rmdir /s /q package

echo Installing dependencies...
pip install -r requirements.txt -t package --upgrade >nul 2>&1

echo Copying files...
xcopy /E /I /Y templates package\templates >nul 2>&1
xcopy /E /I /Y services package\services >nul 2>&1
copy app_simple.py package\ >nul 2>&1
copy .env package\ >nul 2>&1

echo Zipping...
cd package
powershell -command "Compress-Archive -Path * -DestinationPath ..\%PACKAGE_FILE% -Force"
cd ..

echo Package created: %PACKAGE_FILE%
