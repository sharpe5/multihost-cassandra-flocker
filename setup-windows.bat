@echo off
rem First create these directories: 
rem S:\SkyllaDB\volume\testvol1
rem S:\SkyllaDB\volume\testvol2
rem S:\SkyllaDB\volume\testvol3
rem pause

docker volume create --name=testvol1 --opt device=:/s/SkyllaDB/volume/testvol1
docker volume create --name=testvol2 --opt device=:/s/SkyllaDB/volume/testvol2
docker volume create --name=testvol3 --opt device=:/s/SkyllaDB/volume/testvol3
docker network create --subnet=127.0.0.1/24 overlay-net