#copy data.win to mod directory
cd ..
cd ..
cp data.win "mods/Typo Fixes/data.win"
cd "mods/Typo Fixes"

#download quickbms and yoyogames.bms for patching
wget http://aluigi.altervista.org/papers/quickbms.zip
Expand-Archive quickbms.zip QuickBMS
rm quickbms.zip
cd QuickBMS
mv quickbms.exe ..
cd ..
rmdir -r QuickBMS
wget http://aluigi.org/papers/bms/yoyogames.bms

#patch the win file
./quickbms -r -w yoyogames.bms data.win mod > temp.txt
rm temp.txt
rm yoyogames.bms
rm quickbms.exe
rmdir -r mod/
rm patcher.ps1