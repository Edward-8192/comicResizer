# comicResizer
Resize and archive my comic.

It will ...
1. Leverage the ImageMagick tool mogrify to resize and conver image files from jpg/jpeg/png/webp to jpg with "-resize x2800 -quality 80".
2. Remove files with file extension ".txt" and ".url"

[!NOTE]
Please check your disk free space before start.

# Run in MacOS
```
brew update
brew upgrade
brew install imagemagick zip unzip rar p7zip webp rar
```

# Run in Ubuntu
```
apt-get update -y
apt-get upgrade -y
apt-get install imagemagick zip unzip unrar p7zip-full webp -y
```

# Start to resize and archive

1. Move your archived files (e.g. zip, rar, 7z...etc.) to the folder where the script "comicResizer.sh" is.
2. Run script
```
./comicResizer.sh
```