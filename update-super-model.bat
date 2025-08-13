@echo off
echo Updating files from VERA_SuperModel...
git clone git@github.com:gtzook/VERA_SuperModel.git temp-vera
xcopy "temp-vera\*" "classes\GUI\Views\" /Y /Q
rmdir /s /q temp-vera
git add classes\GUI\Views\
echo Files updated! Ready to commit.
pause